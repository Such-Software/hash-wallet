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

# Hash Wallet: monero_c bundles monero, wownero, AND zano as sibling
# submodules. Upstream did `git submodule update --init --recursive` which
# pulled ALL three (and their deep transitive submodules — zano alone drags
# down a ~100MB Qt UI tree we don't need). Init only the coins we ship,
# shallow clones, in parallel.
git submodule deinit -f zano 2>/dev/null || true
rm -rf zano
git submodule update --init --recursive --depth 1 --jobs 8 monero wownero

for coin in monero wownero;
do
    if [[ ! -f "$coin/.patch-applied" ]];
    then
        ./apply_patches.sh $coin
    fi
done
cd ..

echo "monero_c source prepared".
