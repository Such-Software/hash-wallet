#!/bin/sh

APP_LINUX_NAME=""
APP_LINUX_VERSION=""
APP_LINUX_BUILD_VERSION=""

CAKEWALLET="cakewallet"

TYPES=($CAKEWALLET)
APP_LINUX_TYPE=$CAKEWALLET

if [ -n "$1" ]; then
	APP_LINUX_TYPE=$1
fi

# Version and build come from pubspec_description.yaml, the one file every
# platform reads. These said 6.1.0 (79), Cake Wallet's own numbers, which only
# never reached a binary because app_config.sh's substitution looks for a
# version: 0.0.0 placeholder that pubspec_description.yaml does not contain.
_PUBSPEC_VERSION=$(awk -F': ' '/^version:/ {print $2; exit}' "$(dirname "${BASH_SOURCE[0]:-$0}")/../../pubspec_description.yaml")
CAKEWALLET_NAME="Hash Bags"
CAKEWALLET_VERSION="${_PUBSPEC_VERSION%+*}"
CAKEWALLET_BUILD_NUMBER="${_PUBSPEC_VERSION#*+}"

if ! [[ " ${TYPES[*]} " =~ " ${APP_LINUX_TYPE} " ]]; then
    echo "Wrong app type."
    exit 1
fi

case $APP_LINUX_TYPE in
	$CAKEWALLET)
		APP_LINUX_NAME=$CAKEWALLET_NAME
		APP_LINUX_VERSION=$CAKEWALLET_VERSION
		APP_LINUX_BUILD_NUMBER=$CAKEWALLET_BUILD_NUMBER;;
esac

export APP_LINUX_TYPE
export APP_LINUX_NAME
export APP_LINUX_VERSION
export APP_LINUX_BUILD_NUMBER
