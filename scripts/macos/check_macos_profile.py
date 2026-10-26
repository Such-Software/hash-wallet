#!/usr/bin/env python3
"""Choose the signing identity a provisioning profile will actually accept.

Copied from vegan-IQ (scripts/check_macos_profile.py), where it carried the first
Mac App Store build through; Hash Bags uses it for both the Developer ID and the
App Store lanes.

The profile is the constraint, not the certificate. A Mac App Store profile is
built around specific certificates, and signing with any other one fails late,
in a message that blames the certificate for being absent rather than the
profile for having been built without it. So read the profile first and pick
the keychain identity it endorses.

Prints the chosen identity on stdout. Diagnostics go to stderr so the caller
can capture stdout directly.

Exits 0 when the profile cannot be parsed or lists no certificates: those are
different failures, and xcodebuild is entitled to be the one that reports
them. In that case nothing is printed and the caller falls back.
"""

import argparse
import plistlib
import re
import subprocess
import sys

IDENTITY_RE = re.compile(r'"([^"]+)"')
# "subject=UID=X, CN=Apple Distribution: Org (TEAM), OU=..." -> the CN value
CN_RE = re.compile(r"CN\s*=\s*([^,/]+)")


def log(message):
    print(message, file=sys.stderr)


def profile_common_names(profile):
    names = []
    for der in profile.get("DeveloperCertificates", []):
        result = subprocess.run(
            ["openssl", "x509", "-inform", "DER", "-noout", "-subject"],
            input=der,
            capture_output=True,
        )
        if result.returncode != 0:
            continue
        subject = result.stdout.decode("utf-8", "replace").strip()
        match = CN_RE.search(subject)
        if match:
            names.append(match.group(1).strip())
    return names


def keychain_identities(path):
    with open(path) as handle:
        return [
            match.group(1)
            for line in handle
            for match in [IDENTITY_RE.search(line)]
            if match
        ]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--profile", required=True)
    parser.add_argument("--identities", required=True, help="security find-identity output")
    parser.add_argument("--expect-name", required=True)
    args = parser.parse_args()

    try:
        with open(args.profile, "rb") as handle:
            profile = plistlib.load(handle)
    except Exception as exc:
        log("check_macos_profile: cannot parse profile (%s); leaving it to xcodebuild" % exc)
        return 0

    name = profile.get("Name", "")
    if name != args.expect_name:
        log("FATAL: provisioning profile name mismatch.")
        log("  the secret contains:       %s" % (name or "<unnamed>"))
        log("  Runner.xcodeproj asks for: %s" % args.expect_name)
        log("Rename it in the portal, or change PROVISIONING_PROFILE_SPECIFIER.")
        return 1

    wanted = profile_common_names(profile)
    if not wanted:
        log("check_macos_profile: profile lists no certificates; leaving it to xcodebuild")
        return 0

    available = keychain_identities(args.identities)
    for candidate in wanted:
        if candidate in available:
            log("profile %r endorses %r, which is in the keychain" % (name, candidate))
            print(candidate)
            return 0

    log("FATAL: no keychain identity matches this provisioning profile.")
    log("  profile %r was built around:" % name)
    for candidate in wanted:
        log("    %s" % candidate)
    log("  the keychain holds:")
    for identity in available:
        log("    %s" % identity)
    log("")
    log("Either put one of the profile's certificates in this lane's certificate")
    log("secret, or regenerate the profile in the portal around a certificate")
    log("listed above and update this lane's profile secret.")
    return 1


if __name__ == "__main__":
    sys.exit(main())
