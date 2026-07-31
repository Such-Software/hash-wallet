#!/usr/bin/env bash
# Manual screenshot helper (the fast path for a first submission).
# Boot the target simulator, run the app, navigate to a screen, then run this to
# capture it at App-Store-exact dimensions.
#
#   Usage: ./screenshot.sh <name>            # captures the booted simulator
#          OUT_DIR=~/hb-shots ./screenshot.sh 01-home
#
# Recommended flow (on the Mac):
#   xcrun simctl boot "iPhone 16 Pro Max"; open -a Simulator
#   (cd .. && flutter run -d "iPhone 16 Pro Max")   # navigate to each screen, then:
#   ./screenshot.sh 01-home ; ./screenshot.sh 02-receive ; ...
#   # repeat booted on "iPad Pro 13-inch (M4)" for the iPad set.
set -euo pipefail
name="${1:?usage: screenshot.sh <name>}"
out="${OUT_DIR:-./screenshots-manual}"
mkdir -p "$out"
xcrun simctl io booted screenshot "$out/$name.png"
dims=$(python3 -c "import struct;d=open('$out/$name.png','rb').read(26);print('x'.join(map(str,struct.unpack('>II',d[16:24]))))" 2>/dev/null || echo "?")
echo "saved $out/$name.png  ($dims)"
