#!/usr/bin/env bash
# Restore the symlinks of a versioned macOS framework whose archive flattened them.
#
# Usage: relink_framework.sh <Name.framework>
#
# torch_dart's prebuilt tarball is packed on Linux, and tar there stores
# Versions/Current, the top-level binary and Resources as full copies of
# Versions/A. codesign then calls the bundle "ambiguous (could be app or
# framework)" and refuses to sign the app around it. A versioned framework
# needs exactly:
#   Versions/Current -> A
#   <Name>           -> Versions/Current/<Name>
#   Resources        -> Versions/Current/Resources
# Every copy is compared with Versions/A before it is replaced, so this never
# throws away a file that differs.
set -euo pipefail

[ $# -eq 1 ] || { echo "usage: $0 <Name.framework>" >&2; exit 64; }
fw=${1%/}
name=$(basename "$fw" .framework)
[ -f "$fw/Versions/A/$name" ] || {
    echo "FATAL: $fw has no Versions/A/$name; not a versioned framework" >&2; exit 1; }

same() {   # same <path> <reference>: the copy exists and matches Versions/A
    [ -L "$1" ] && return 1
    diff -r "$1" "$2" >/dev/null || {
        echo "FATAL: $1 differs from $2; refusing to replace it with a symlink" >&2; exit 1; }
}

relink() { # relink <path> <target>
    if [ -L "$fw/$1" ]; then
        [ "$(readlink "$fw/$1")" = "$2" ] || {
            echo "FATAL: $fw/$1 points at $(readlink "$fw/$1"), not $2" >&2; exit 1; }
        return
    fi
    rm -rf "${fw:?}/$1"
    ln -s "$2" "$fw/$1"
    echo "relinked $fw/$1 -> $2"
}

[ -e "$fw/Versions/Current" ] && ! [ -L "$fw/Versions/Current" ] && same "$fw/Versions/Current" "$fw/Versions/A"
relink Versions/Current A
[ -e "$fw/$name" ] && ! [ -L "$fw/$name" ] && same "$fw/$name" "$fw/Versions/A/$name"
relink "$name" "Versions/Current/$name"
if [ -d "$fw/Versions/A/Resources" ]; then
    [ -e "$fw/Resources" ] && ! [ -L "$fw/Resources" ] && same "$fw/Resources" "$fw/Versions/A/Resources"
    relink Resources Versions/Current/Resources
fi
