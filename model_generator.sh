#!/bin/bash
set -x -e

# Hash Bags: trimmed to chains we actually ship. The disabled ones
# (solana, tron, zano, decred, zcash) still have their cw_* directories on
# disk but aren't in pubspec.yaml, so running build_runner on them is just
# wasted minutes. Add a chain back to this list if you re-enable it in
# scripts/{ios,android,linux,macos}/app_config.sh + pubspec_gen.sh.
for cwcoin in cw_{core,evm,monero,bitcoin,nano,bitcoin_cash,wownero,dogecoin}
do
    if [[ "x$1" == "xasync" ]];
    then
        bash -c "cd $cwcoin; flutter pub get; dart run build_runner build --delete-conflicting-outputs; cd .." &
    else
        cd $cwcoin; flutter pub get; dart run build_runner build --delete-conflicting-outputs; cd ..
    fi
done
for cwcoin in cw_mweb;
do
    if [[ "x$1" == "xasync" ]];
    then
        bash -c "cd $cwcoin; flutter pub get; cd .." &
    else
        cd $cwcoin; flutter pub get; cd ..
    fi
done

flutter pub get
dart run build_runner build --delete-conflicting-outputs
