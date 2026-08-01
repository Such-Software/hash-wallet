#!/bin/bash

set -x -e

cd "$(dirname "$0")"

if [[ ! -d "monero_c/.git" ]];
then
    rm -rf monero_c
    git clone https://github.com/mrcyjanek/monero_c --branch master monero_c
    cd monero_c
else
    cd monero_c
fi

# NOTE: Make sure to update monero_c prebuilds link in workflow files
# https://github.com/MrCyjaneK/monero_c/releases/download/v0.18.4.6-RC1/release-bundle.zip
git fetch -a
git checkout bc8d1a0b75b97156d71579581b4cdfe58c777ed2
git reset --hard

# Hash Bags: every CI workflow (android/ios-sim/ios-testflight/linux/windows)
# consumes PREBUILT .so/.a files from monero_c's release-bundle.zip. None of
# them compile monero_c from source. The only thing they need out of this
# checkout is `git describe --tags`, which resolves the release/<tag>/ path.
#
# So by default we do NOT init the monero/wownero submodules. Besides saving
# ~1GB of source plus deep transitive submodules per CI run, this decouples us
# from where Wownero is hosted:
#
#   Wownero left Codeberg in July 2026 (Codeberg announced it would ban crypto
#   projects) and remigrated to https://github.com/wownero/wownero. monero_c's
#   .gitmodules still points at the dead Codeberg URLs, which now fail with
#   "remote: Bye" / HTTP 403. That is what broke the iOS TestFlight build on
#   2026-07-31 — at a step that never needed the source in the first place.
#
# Set MONERO_C_BUILD_FROM_SOURCE=1 only if you genuinely intend to compile
# monero_c yourself. See the caveat below before you do.
if [[ "${MONERO_C_BUILD_FROM_SOURCE:-0}" == "1" ]];
then
    # zano is a sibling submodule we never ship — skip it (its Qt UI tree alone
    # is ~100MB).
    git submodule deinit -f zano 2>/dev/null || true
    rm -rf zano

    # Redirect the dead Codeberg URLs to where the code actually lives now.
    # Safe despite being a host swap: both submodules are pinned to exact
    # commit SHAs, and git verifies the object hash on fetch, so a different
    # host cannot substitute different content under the same SHA.
    #
    #   wownero   -> github.com/wownero/wownero (canonical since the July 2026
    #                remigration off Codeberg)
    #   randomwow -> github.com/mrcyjanek/randomwow, which is what monero_c
    #                itself switches the remote to in apply_patches.sh. Note
    #                this is NOT github.com/wownero/RandomWOW — that one is a
    #                fork of tevador/RandomX on a different lineage and does
    #                not contain the pinned commit. The redirect has to happen
    #                here because apply_patches.sh only runs AFTER the clone
    #                that would otherwise fail against Codeberg.
    git \
      -c url."https://github.com/wownero/wownero".insteadOf="https://codeberg.org/wownero/wownero" \
      -c url."https://github.com/mrcyjanek/randomwow".insteadOf="https://codeberg.org/wownero/RandomWOW" \
      submodule update --init --recursive --depth 1 --jobs 8 monero wownero

    for coin in monero wownero;
    do
        if [[ ! -f "$coin/.patch-applied" ]];
        then
            ./apply_patches.sh $coin
        fi
    done
    cd ..
    echo "monero_c source prepared (full source checkout)."
else
    cd ..
    echo "monero_c prepared (prebuilt mode — submodules intentionally skipped)."
fi
