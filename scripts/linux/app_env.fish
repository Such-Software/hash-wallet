#!/usr/bin/env fish

set -g APP_LINUX_NAME ""
set -g APP_LINUX_VERSION ""
set -g APP_LINUX_BUILD_NUMBER ""

set -g CAKEWALLET "cakewallet"

set -g TYPES $CAKEWALLET
set -g APP_LINUX_TYPE $CAKEWALLET

if test -n "$argv[1]"
    set -g APP_LINUX_TYPE $argv[1]
end

set -g CAKEWALLET_NAME "Cake Wallet"
# From pubspec_description.yaml, like app_env.sh. These were Cake's 1.9.0 (29).
set -l _pubspec_version (awk -F': ' '/^version:/ {print $2; exit}' (dirname (status --current-filename))/../../pubspec_description.yaml)
set -g CAKEWALLET_VERSION (string split -f1 '+' $_pubspec_version)
set -g CAKEWALLET_BUILD_NUMBER (string split -f2 '+' $_pubspec_version)

if not contains -- $APP_LINUX_TYPE $TYPES
    echo "Wrong app type."
    exit 1
end

switch $APP_LINUX_TYPE
    case $CAKEWALLET
        set -g APP_LINUX_NAME $CAKEWALLET_NAME
        set -g APP_LINUX_VERSION $CAKEWALLET_VERSION
        set -g APP_LINUX_BUILD_NUMBER $CAKEWALLET_BUILD_NUMBER
end

export APP_LINUX_TYPE
export APP_LINUX_NAME
export APP_LINUX_VERSION
export APP_LINUX_BUILD_NUMBER
