#!/bin/bash
# Load a merge of an upstream Cake Wallet ref into the working tree, with the
# two mechanical differences between the forks normalized away first:
#   1. our project rename (package:cake_wallet/ -> package:hash_wallet/ imports)
#   2. formatting (upstream formats Dart at 100 columns, short style)
# Without this the 6.5.0 sync showed 614 conflicting paths; with it, 322.
#
# Usage: scripts/upstream_sync.sh <upstream-ref>    e.g. v6.6.0
# Run on a fresh sync branch with a clean tree. Afterwards resolve conflicts
# as usual (git status), then `git commit`: MERGE_HEAD is the real upstream
# commit, so the next sync's merge base is correct.
set -euo pipefail

ref="${1:?usage: $0 <upstream-ref>}"
dart="${DART:-dart}"
fmt=(format --page-width 100 --language-version=3.0)

cd "$(git rev-parse --show-toplevel)"
if [[ -n "$(git status --porcelain)" ]]; then
  echo "refusing: working tree is not clean" >&2
  exit 1
fi
git rev-parse -q --verify "$ref^{commit}" >/dev/null || { echo "refusing: unknown ref $ref" >&2; exit 1; }

# Our side: keep it formatted the way upstream is, as a real commit.
git ls-files -z '*.dart' | xargs -0 "$dart" "${fmt[@]}" >/dev/null 2>&1 || true
if [[ -n "$(git status --porcelain)" ]]; then
  git commit -qam "style: format Dart at 100 columns, as upstream does"
fi

base=$(git merge-base HEAD "$ref")
tmp=$(mktemp -d)
trap 'git worktree remove --force "$tmp/base" 2>/dev/null || true; git worktree remove --force "$tmp/theirs" 2>/dev/null || true; rm -rf "$tmp"' EXIT

normalize() { # <dir> <format?>
  (
    cd "$1"
    git grep -lz 'package:cake_wallet/' -- '*.dart' | xargs -0 -r sed -i 's#package:cake_wallet/#package:hash_wallet/#g'
    if [[ "$2" == format ]]; then
      git ls-files -z '*.dart' | xargs -0 "$dart" "${fmt[@]}" >/dev/null 2>&1 || true
    fi
    git -c user.name=normalize -c user.email=normalize@localhost commit -qam normalize --allow-empty
    git rev-parse HEAD
  )
}

umask 022
git worktree add -q --detach "$tmp/base" "$base"
git worktree add -q --detach "$tmp/theirs" "$ref"
nbase=$(normalize "$tmp/base" format)
ntheirs=$(normalize "$tmp/theirs" keep)

git read-tree -m -u "$nbase" HEAD "$ntheirs"
git merge-index -o -q git-merge-one-file -a || true
git rev-parse "$ref^{commit}" > "$(git rev-parse --git-dir)/MERGE_HEAD"
echo "Merge upstream Cake Wallet $ref" > "$(git rev-parse --git-dir)/MERGE_MSG"

echo "Merge of $ref loaded. Unmerged paths:"
git diff --name-only --diff-filter=U | wc -l
