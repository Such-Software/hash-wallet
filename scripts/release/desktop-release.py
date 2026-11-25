"""Stage and check a Hash Bags desktop release without publishing the draft."""

import argparse
import json
from pathlib import Path
import re
import subprocess
import sys


REPO = "Such-Software/hash-wallet"
BUILDS = "Builds/hash-wallet"
SOURCE_BRANCH = "refs/heads/dev"
SCRIPT = "scripts/release/desktop-release.py"
REMOTE_URLS = {
    "origin": {f"git@github.com:{REPO}.git", f"https://github.com/{REPO}.git"},
    "gitea-builds": {
        f"such-git@git.such.software:{BUILDS}.git",
        f"ssh://such-git@git.such.software:2222/{BUILDS}.git",
    },
}


def command(*args):
    return subprocess.check_output(args, text=True).strip()


def verify_remote(name):
    allowed = {url.lower() for url in REMOTE_URLS[name]}
    for direction in ([], ["--push"]):
        urls = command("git", "remote", "get-url", *direction, "--all", name).splitlines()
        if len(urls) != 1 or urls[0].lower() not in allowed:
            raise ValueError(f"{name} does not have the expected fetch and push destinations")


def remote_refs(remote, *refs):
    return {
        ref: sha
        for sha, ref in (line.split() for line in command("git", "ls-remote", remote, *refs).splitlines())
    }


def remote_tag(remote, ref):
    peeled = f"{ref}^{{}}"
    refs = remote_refs(remote, ref, peeled)
    return refs.get(peeled, refs.get(ref))


def release_for(tag):
    raw = command("gh", "api", "--paginate", f"repos/{REPO}/releases?per_page=100")
    decoder = json.JSONDecoder()
    matches = []
    while raw:
        page, end = decoder.raw_decode(raw)
        matches.extend(release for release in page if release["tag_name"] == tag)
        raw = raw[end:].lstrip()
    if len(matches) > 1:
        raise ValueError(f"GitHub returned more than one release for {tag}")
    return matches[0] if matches else None


def verify_assets(release, names):
    assets = {asset["name"]: asset for asset in release["assets"]}
    missing = []
    for name in names:
        asset = assets.get(name, {})
        if (asset.get("state") != "uploaded" or asset.get("size", 0) <= 0
                or not re.fullmatch(r"sha256:[0-9a-f]{64}", asset.get("digest") or "")):
            missing.append(name)
        else:
            print(f"{name}  {asset['digest']}")
    if missing:
        raise ValueError("Desktop assets are missing or unverified: " + ", ".join(missing))


def has_release_driver(commit):
    source = subprocess.run(
        ["git", "show", f"{commit}:{SCRIPT}"], capture_output=True, text=True,
    )
    return source.returncode == 0 and source.stdout.strip() == Path(__file__).read_text().strip()


def stage(commit, tag, version, ref, canonical, builds, release):
    if not has_release_driver(commit):
        raise ValueError("The exact release commit does not contain this desktop release automation")
    if release is not None and not release["draft"]:
        raise ValueError(f"GitHub release {tag} is already public")
    if builds is not None and (canonical is None or release is None):
        raise ValueError(f"Builds tag {tag} already exists without its expected GitHub tag and draft")
    if canonical is None:
        subprocess.run(["git", "push", "origin", f"{commit}:{ref}"], check=True)
    if release is None:
        subprocess.run(
            ["gh", "release", "create", tag, "--repo", REPO, "--draft", "--verify-tag",
             "--title", f"Hash Bags {version}", "--notes", ""],
            check=True,
        )
        release = release_for(tag)
    if release is None or not release["draft"] or remote_tag("origin", ref) != commit:
        raise ValueError("GitHub did not confirm the exact release tag and draft")
    if builds is None:
        subprocess.run(["git", "push", "gitea-builds", f"{commit}:{ref}"], check=True)
    if remote_tag("gitea-builds", ref) != commit:
        raise ValueError(f"Builds did not confirm tag {tag} at {commit}")
    print(f"Desktop build tag confirmed: {tag}")
    print(release["html_url"])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("commit", help="Full reviewed canonical Git commit")
    operation = parser.add_mutually_exclusive_group()
    operation.add_argument("--start", action="store_true", help="Create the draft and start the desktop tag builds")
    operation.add_argument("--verify", action="store_true", help="Check the three GitHub asset names and digests")
    args = parser.parse_args()
    if not re.fullmatch(r"[0-9a-f]{40}", args.commit):
        parser.error("commit must be a full lowercase Git SHA")

    for remote in REMOTE_URLS:
        verify_remote(remote)
    head = remote_refs("origin", SOURCE_BRANCH).get(SOURCE_BRANCH)
    if head is None:
        raise ValueError("Canonical dev did not return a commit")
    ancestry = subprocess.run(["git", "merge-base", "--is-ancestor", args.commit, head])
    if ancestry.returncode != 0:
        raise ValueError("The commit is not on locally available canonical dev history. Fetch origin dev if it moved.")

    spec = command("git", "show", f"{args.commit}:pubspec_description.yaml")
    match = re.search(r"^version:\s+([0-9]+\.[0-9]+\.[0-9]+)\+([1-9][0-9]*)$", spec, re.MULTILINE)
    if not match:
        raise ValueError("Expected a version and positive build number in pubspec_description.yaml")
    version, build = match.groups()
    tag = f"hash-bags-{version}-build{build}"
    ref = f"refs/tags/{tag}"
    canonical = remote_tag("origin", ref)
    builds = remote_tag("gitea-builds", ref)
    if any(sha is not None and sha != args.commit for sha in (canonical, builds)):
        raise ValueError(f"Tag {tag} already points at a different commit")
    release = release_for(tag)
    names = [f"{tag}-macos.zip", f"HashBags-windows-{tag}.zip", "Hash_Bags-x86_64.AppImage"]
    print(f"{tag} at {args.commit}")
    if args.start:
        stage(args.commit, tag, version, ref, canonical, builds, release)
    elif args.verify:
        if canonical is None or builds is None or release is None:
            raise ValueError("The GitHub tag, Builds tag, and GitHub release must all exist")
        verify_assets(release, names)
        print(release["html_url"])
    else:
        print("Desktop assets: " + ", ".join(names))
        if has_release_driver(args.commit):
            print("Use --start to stage the draft and trigger the desktop tag builds.")
        else:
            print("This commit predates the desktop tag workflow or carries a different release command.")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, subprocess.SubprocessError) as error:
        sys.exit(f"Desktop release failed: {error}")
