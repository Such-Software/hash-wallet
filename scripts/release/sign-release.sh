#!/usr/bin/env bash
# sign-release.sh: detach-sign every shipped desktop artifact, and verify.
#
# Same shape as smirk's, deliberately: one person verifies downloads from both
# products and should not have to learn two procedures.
#
#   windows : HashBags-windows-<tag>.zip
#   macos   : HashBags-macos-<version>.zip
#   linux   : Hash_Bags-x86_64.AppImage
#
# Each artifact gets a detached ASCII signature beside it (<file>.asc), and
# SHA256SUMS is written and signed too. Signing the sums file is the one that
# matters most: it is what lets someone verify a download that reached them
# from a mirror or a store page, where the .asc never travelled with the file.
#
# Usage:
#   scripts/release/sign-release.sh 1.0.3 --dir ~/release-1.0.3
#   scripts/release/sign-release.sh 1.0.3 --dir ~/release-1.0.3 --verify
#   HASHBAGS_SIGNING_KEY=<keyid!> scripts/release/sign-release.sh 1.0.3 --dir ...
#
# HASHBAGS_SIGNING_KEY should name the RELEASE SIGNING SUBKEY, not the primary,
# and should carry a trailing exclamation mark so gpg uses exactly that subkey
# rather than choosing one itself. The primary never needs to be present on a
# build machine, and is not needed here.
set -euo pipefail

fail() { echo "sign-release: $1" >&2; exit 1; }

VERSION="${1:-}"
if [ -z "$VERSION" ] || [ "$VERSION" = "-h" ] || [ "$VERSION" = "--help" ]; then
  sed -n '2,27p' "$0" | sed 's/^# \{0,1\}//'
  exit 2
fi
shift

DIR=""
VERIFY_ONLY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --dir)    DIR="${2:-}"; shift 2 ;;
    --verify) VERIFY_ONLY=1; shift ;;
    *) fail "unknown argument: $1" ;;
  esac
done
[ -n "$DIR" ] || fail "no --dir. Where are the downloaded artifacts?"
[ -d "$DIR" ] || fail "no such directory: $DIR"

# The company release key. One key covers Hash Bags and Smirk, which is a
# deliberate choice: the fingerprint a user is asked to trust belongs to Such
# Software rather than to a product, so it does not have to be re-learned per
# app. The cost is that rotating it affects everything, which is why the
# primary stays offline and only this subkey signs.
KEY="${HASHBAGS_SIGNING_KEY:-96F6836D5110C2CB!}"

command -v gpg >/dev/null || fail "gpg is not installed"

cd "$DIR"
shopt -s nullglob
FILES=( HashBags-windows-*.zip HashBags-macos-*.zip Hash_Bags-*.AppImage *.dmg *.deb )
[ ${#FILES[@]} -gt 0 ] || fail "no release artifacts found in $DIR"

echo "artifacts in $DIR:"
printf '  %s\n' "${FILES[@]}"
echo

if [ "$VERIFY_ONLY" -eq 0 ]; then
  # SHA256SUMS first, so the signature covers the final set rather than a set
  # that grew afterwards.
  : > SHA256SUMS
  for f in "${FILES[@]}"; do
    if command -v sha256sum >/dev/null; then sha256sum "$f" >> SHA256SUMS
    else shasum -a 256 "$f" >> SHA256SUMS; fi
  done
  cat SHA256SUMS
  echo

  for f in "${FILES[@]}" SHA256SUMS; do
    rm -f "$f.asc"
    gpg --local-user "$KEY" --armor --detach-sign --output "$f.asc" "$f"
    echo "signed $f"
  done
  echo
fi

# Verify unconditionally, including right after signing. A signature that was
# written but cannot be checked is worth less than none, because it invites
# trust it has not earned.
rc=0
for f in "${FILES[@]}" SHA256SUMS; do
  [ -f "$f.asc" ] || { echo "MISSING SIGNATURE: $f.asc"; rc=1; continue; }
  if gpg --verify "$f.asc" "$f" 2>/dev/null; then
    echo "verified $f"
  else
    echo "VERIFY FAILED: $f"; rc=1
  fi
done
[ "$rc" -eq 0 ] || fail "one or more artifacts did not verify"
echo
echo "all artifacts signed and verified for $VERSION"
