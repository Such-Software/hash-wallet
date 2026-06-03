#!/bin/sh

APP_IOS_NAME=""
APP_IOS_VERSION=""
APP_IOS_BUILD_VERSION=""
APP_IOS_BUNDLE_ID=""

MONERO_COM="monero.com"
CAKEWALLET="cakewallet"

TYPES=($MONERO_COM $CAKEWALLET)
APP_IOS_TYPE=$1

MONERO_COM_NAME="Monero.com"
MONERO_COM_VERSION="6.1.2"
MONERO_COM_BUILD_NUMBER=163
MONERO_COM_BUNDLE_ID="com.cakewallet.monero"

# Source CAKEWALLET version + build number from pubspec_description.yaml
# (single source of truth). Without this, the hardcoded build number
# here silently overrode pubspec via app_config.sh's PlistBuddy step,
# so iOS uploads all shipped as the same CFBundleVersion and Apple
# rejected duplicates.
_PUBSPEC_VERSION=$(awk -F': ' '/^version:/ {print $2; exit}' ../../pubspec_description.yaml)
CAKEWALLET_NAME="Hash Bags"
CAKEWALLET_VERSION="${_PUBSPEC_VERSION%+*}"
CAKEWALLET_BUILD_NUMBER="${_PUBSPEC_VERSION#*+}"
CAKEWALLET_BUNDLE_ID="com.suchsoftware.hashwallet"


if ! [[ " ${TYPES[*]} " =~ " ${APP_IOS_TYPE} " ]]; then
    echo "Wrong app type."
    exit 1
fi

case $APP_IOS_TYPE in
	$MONERO_COM)
		APP_IOS_NAME=$MONERO_COM_NAME
		APP_IOS_VERSION=$MONERO_COM_VERSION
		APP_IOS_BUILD_NUMBER=$MONERO_COM_BUILD_NUMBER
		APP_IOS_BUNDLE_ID=$MONERO_COM_BUNDLE_ID
		;;
	$CAKEWALLET)
		APP_IOS_NAME=$CAKEWALLET_NAME
		APP_IOS_VERSION=$CAKEWALLET_VERSION
		APP_IOS_BUILD_NUMBER=$CAKEWALLET_BUILD_NUMBER
		APP_IOS_BUNDLE_ID=$CAKEWALLET_BUNDLE_ID
		;;
	$HAVEN)
		APP_IOS_NAME=$HAVEN_NAME
		APP_IOS_VERSION=$HAVEN_VERSION
		APP_IOS_BUILD_NUMBER=$HAVEN_BUILD_NUMBER
		APP_IOS_BUNDLE_ID=$HAVEN_BUNDLE_ID
		;;
esac

export APP_IOS_TYPE
export APP_IOS_NAME
export APP_IOS_VERSION
export APP_IOS_BUILD_NUMBER
export APP_IOS_BUNDLE_ID
