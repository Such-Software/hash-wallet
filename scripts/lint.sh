#!/bin/bash
set -e
cd "$(dirname "$0")"
cd ..

for i in cw_core cw_monero cw_wownero cw_bitcoin cw_bitcoin_cash cw_dogecoin cw_evm cw_nano;
do
    {
        # files modified after the lints got enabled and committed
        git log --since="2026-07-14 23:59:59" --name-only --diff-filter=d --format="" -- "$i"
        # uncommitted files (assumed to have been modified after the 29th)
        git diff --name-only --diff-filter=d HEAD -- "$i"
    } | grep '\.dart$' | sort -u | while IFS= read -r file; do
        echo $file
        if [[ -f "$file" ]]; then
            dart fix --apply "$file" && dart format --line-length=100 "$file"
        fi
    done

    if [[ -n "$ABORT_ON_CHANGE" ]]; then
        DART_CHANGES=$(git status --porcelain -- "$i" | grep '\.dart$' || true)

        if [[ -n "$DART_CHANGES" ]]; then
            echo "Please run scripts/lint.sh"
            echo "changes in $i:"
            echo "$DART_CHANGES"
            exit 1
        fi
    fi
done
