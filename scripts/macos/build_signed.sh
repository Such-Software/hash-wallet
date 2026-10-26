#!/usr/bin/env bash
# Build and sign Hash Bags for macOS against one provisioning profile.
#
# Usage: build_signed.sh <profile.provisionprofile> <keychain> <derived-data-dir> [setting=value ...]
# Run from the repository root after `flutter build macos --release --config-only`.
# Prints the built .app's path as the last line of stdout; build output goes to stderr.
#
# Signing happens inside xcodebuild, never afterwards. Xcode then expands the
# entitlements' $(AppIdentifierPrefix), embeds the profile, and signs every nested
# dylib and framework with the same identity. Re-signing a finished .app by hand
# did none of that: the keychain group shipped as a literal "$(AppIdentifierPrefix)"
# string and the app had no profile to authorise it.
#
# The profile decides the identity. check_macos_profile.py reads the certificates it
# was issued for and picks the one the keychain holds, so a Developer ID profile
# cannot be paired with the App Store certificate or the other way round.
set -euo pipefail

[ $# -ge 3 ] || { echo "usage: $0 <profile> <keychain> <derived-data-dir> [setting=value ...]" >&2; exit 64; }
profile=$1 keychain=$2 derived=$3
shift 3

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

security cms -D -i "$profile" > "$work/profile.plist"
name="$(/usr/libexec/PlistBuddy -c 'Print :Name' "$work/profile.plist")"
uuid="$(/usr/libexec/PlistBuddy -c 'Print :UUID' "$work/profile.plist")"
team="$(/usr/libexec/PlistBuddy -c 'Print :TeamIdentifier:0' "$work/profile.plist")"
echo "profile: $name ($uuid), team $team" >&2

# Xcode 16 reads UserData; older Xcode reads MobileDevice. Both, by UUID, which is
# what Xcode matches on after resolving the specifier.
for dir in "$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles" \
           "$HOME/Library/MobileDevice/Provisioning Profiles"; do
    mkdir -p "$dir"
    cp "$profile" "$dir/$uuid.provisionprofile"
done

security find-identity -v -p codesigning "$keychain" > "$work/identities.txt"
identity="$(python3 scripts/macos/check_macos_profile.py \
    --profile "$work/profile.plist" --identities "$work/identities.txt" --expect-name "$name")"
if [ -z "$identity" ]; then
    # The checker declines only when the profile lists no readable certificate. With
    # two lanes in one keychain, guessing could sign with the other lane's identity.
    echo "FATAL: profile '$name' names no certificate this build can match; refusing to guess." >&2
    exit 1
fi
echo "signing identity: $identity" >&2

# The profile specifier is a Runner-only setting (project.pbxproj reads it from
# HASH_BAGS_MACOS_PROFILE), so the pods never see a profile they would refuse.
xcodebuild -workspace macos/Runner.xcworkspace -scheme Runner \
    -configuration Release -derivedDataPath "$derived" \
    CODE_SIGN_IDENTITY="$identity" \
    DEVELOPMENT_TEAM="$team" \
    HASH_BAGS_MACOS_PROFILE="$name" \
    OTHER_CODE_SIGN_FLAGS="--keychain $keychain --timestamp" \
    "$@" build >&2

app="$(find "$derived/Build/Products/Release" -maxdepth 1 -name '*.app' | head -1)"
[ -n "$app" ] || { echo "FATAL: xcodebuild produced no .app under $derived" >&2; exit 1; }
codesign --verify --deep --strict --verbose=2 "$app" >&2

codesign -d --entitlements - --xml "$app" > "$work/entitlements.plist" 2>/dev/null
if grep -q '\$(' "$work/entitlements.plist"; then
    echo "FATAL: the signed entitlements still hold an unexpanded build variable:" >&2
    grep '\$(' "$work/entitlements.plist" >&2
    exit 1
fi
[ -f "$app/Contents/embedded.provisionprofile" ] || {
    echo "FATAL: $app carries no embedded provisioning profile" >&2; exit 1; }

echo "$app"
