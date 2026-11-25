"""Attach an immutable desktop asset to an existing Hash Bags release."""

import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen


REPO = "Such-Software/hash-wallet"
API = f"https://api.github.com/repos/{REPO}"


def request(url, *, asset=None):
    token = os.environ.get("GH_TOKEN")
    if not token:
        raise ValueError("GH_RELEASE_TOKEN is missing")
    headers = {
        "Accept": "application/vnd.github+json",
        "User-Agent": "hash-bags-ci",
    }
    if asset is None:
        attempt = Request(url, headers=headers)
        attempt.add_unredirected_header("Authorization", f"Bearer {token}")
        with urlopen(attempt, timeout=30) as response:
            return json.load(response)
    headers["Content-Type"] = "application/octet-stream"
    headers["Content-Length"] = str(asset.stat().st_size)
    with asset.open("rb") as handle:
        attempt = Request(url, data=handle, headers=headers)
        attempt.add_unredirected_header("Authorization", f"Bearer {token}")
        with urlopen(attempt, timeout=600) as response:
            return json.load(response)


def find_release(tag):
    page = 1
    while True:
        releases = request(f"{API}/releases?per_page=100&page={page}")
        for release in releases:
            if release["tag_name"] == tag:
                return release
        if len(releases) < 100:
            raise ValueError(f"GitHub release {tag} does not exist")
        page += 1


def verify_tag(tag):
    ref = f"refs/tags/{tag}"
    output = subprocess.check_output(
        ["git", "ls-remote", f"https://github.com/{REPO}.git", ref, f"{ref}^{{}}"],
        text=True,
        timeout=30,
    )
    refs = dict(reversed(line.split()) for line in output.splitlines())
    sha = refs.get(f"{ref}^{{}}", refs.get(ref))
    if sha is None or sha != os.environ.get("GITHUB_SHA"):
        raise ValueError(f"GitHub tag {tag} does not point to the build commit")


def publish(tag, asset):
    if not asset.is_file() or asset.stat().st_size == 0:
        raise ValueError(f"Desktop asset is missing or empty: {asset}")
    release = find_release(tag)
    if os.environ.get("GITHUB_EVENT_NAME") == "push":
        verify_tag(tag)
        if not release["draft"]:
            raise ValueError(f"Tag builds may only attach assets to a draft release: {tag}")

    digest = hashlib.sha256()
    with asset.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    expected_digest = f"sha256:{digest.hexdigest()}"

    existing = next((item for item in release["assets"] if item["name"] == asset.name), None)
    if existing is not None:
        if existing.get("state") != "uploaded" or existing.get("digest") != expected_digest:
            raise ValueError(f"GitHub already has a different or incomplete asset named {asset.name}")
        print(f"{asset.name} is already uploaded with the expected digest")
        return

    upload_url = f"https://uploads.github.com/repos/{REPO}/releases/{release['id']}/assets"
    uploaded = request(f"{upload_url}?{urlencode({'name': asset.name})}", asset=asset)
    if uploaded.get("state") != "uploaded" or uploaded.get("digest") != expected_digest:
        raise ValueError(f"GitHub did not confirm the expected digest for {asset.name}")
    print(f"Uploaded {asset.name} to GitHub release {tag}")


if __name__ == "__main__":
    try:
        tag, filename = sys.argv[1:]
        publish(tag, Path(filename))
    except HTTPError as error:
        sys.exit(f"Desktop asset upload refused by GitHub (HTTP {error.code})")
    except (ValueError, URLError, OSError, subprocess.SubprocessError) as error:
        sys.exit(f"Desktop asset upload failed: {error}")
