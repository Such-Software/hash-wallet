#!/usr/bin/env bash
# Build a Hash Bags APK locally using the SAME container image CI uses.
#
# Why a container: this repo pins Flutter 3.32.0. A newer host Flutter (3.38+)
# cannot resolve the dependency set at all -- hive_generator wants an analyzer
# that still ships the `macros` package, which newer Dart SDKs removed. Rather
# than fight that, we build inside
#   ghcr.io/cake-tech/cake_wallet:debian13-flutter3.32.0-ndkr28-go1.24.1-ruststablenightly
# which is exactly what .github/workflows/build-android.yml uses.
#
# Usage:
#   tools/demo/build-apk.sh                 # debug, x86_64 (emulator capture)
#   BUILD_MODE=release ABI=arm64 tools/demo/build-apk.sh
#   SKIP_DEPS=1 tools/demo/build-apk.sh     # re-build only, deps already fetched
#
# The container runs as root (FLUTTER_ROOT lives under /root in the image), so
# the script chowns everything back to the invoking user on exit -- otherwise
# you get root-owned build artifacts scattered through your worktree.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Pull in local capture config (DEMO_WALLET_SEED/HEIGHT/PIN). Gitignored.
_DEMO_ENV="$(dirname "${BASH_SOURCE[0]}")/demo.env"
if [[ -f "$_DEMO_ENV" ]]; then set -a; . "$_DEMO_ENV"; set +a; fi
IMAGE="${CI_IMAGE:-ghcr.io/cake-tech/cake_wallet:debian13-flutter3.32.0-ndkr28-go1.24.1-ruststablenightly}"
BUILD_MODE="${BUILD_MODE:-debug}"
ABI="${ABI:-x86_64}"
SKIP_DEPS="${SKIP_DEPS:-0}"
HOST_UID="$(id -u)"
HOST_GID="$(id -g)"

case "$ABI" in
  x86_64) TARGET_PLATFORM="android-x64" ;;
  arm64)  TARGET_PLATFORM="android-arm64" ;;
  all)    TARGET_PLATFORM="" ;;
  *) echo "ABI must be x86_64 | arm64 | all" >&2; exit 1 ;;
esac

echo "==> image      $IMAGE"
echo "==> mode       $BUILD_MODE"
echo "==> abi        $ABI (${TARGET_PLATFORM:-universal})"
echo "==> repo       $REPO_ROOT"

docker run --rm \
  --network host \
  -v "$REPO_ROOT":/work \
  -w /work \
  -e SKIP_DEPS="$SKIP_DEPS" \
  -e BUILD_MODE="$BUILD_MODE" \
  -e TARGET_PLATFORM="$TARGET_PLATFORM" \
  -e DEMO="${DEMO:-0}" \
  -e DEMO_PIN="${DEMO_PIN:-0801}" \
  -e DEMO_WALLET_SEED="${DEMO_WALLET_SEED:-}" \
  -e DEMO_WALLET_HEIGHT="${DEMO_WALLET_HEIGHT:-0}" \
  -e HOST_UID="$HOST_UID" \
  -e HOST_GID="$HOST_GID" \
  "$IMAGE" bash -c '
set -euo pipefail
# Chown back on ANY exit path so a failed build does not leave a root-owned
# worktree behind.
trap "chown -R ${HOST_UID}:${HOST_GID} /work 2>/dev/null || true" EXIT

git config --global --add safe.directory "*"

step() { echo; echo "########## $* ##########"; }

if [[ "$SKIP_DEPS" != "1" ]]; then
  step "torch_dart prebuilt"
  pushd scripts >/dev/null
    if [[ ! -d torch_dart ]]; then
      wget -q https://github.com/MrCyjaneK/torch_dart/releases/download/v1.0.17/torch_dart-v1.0.17.tar.gz -O torch_dart.tar.gz
      mkdir -p torch_dart && tar -xzf torch_dart.tar.gz -C torch_dart && rm torch_dart.tar.gz
    else echo "already present"; fi
  popd >/dev/null

  step "reown_flutter prebuilt"
  pushd scripts >/dev/null
    if [[ ! -d reown_flutter ]]; then
      wget -q https://github.com/cake-tech/reown_flutter/releases/download/v0.0.4/reown_flutter-v0.0.4.tar.gz -O reown_flutter.tar.gz
      mkdir -p reown_flutter && tar -xzf reown_flutter.tar.gz -C reown_flutter && rm reown_flutter.tar.gz
    else echo "already present"; fi
  popd >/dev/null

  step "bitbox flutter"
  # Guard on the ARTIFACT, not the directory. A half-finished checkout with no
  # api.aar looks "done" by directory alone, and gradle then fails deep into
  # assembleDebug with an opaque "Could not find :api:".
  pushd scripts >/dev/null
    if [[ -e bitbox_flutter/go/api/api.aar ]]; then
      echo "api.aar already built"
    else
      ./build_bitbox_flutter.sh
    fi
  popd >/dev/null

  step "monero_c prebuilt .so bundle"
  ./scripts/prepare_moneroc.sh
  MONERO_C_TAG=$(cd scripts/monero_c && git describe --tags)
  echo "monero_c TAG: $MONERO_C_TAG"
  BUNDLE_DIR="scripts/monero_c/release/$MONERO_C_TAG"
  mkdir -p "$BUNDLE_DIR"
  if [[ ! -d "$BUNDLE_DIR/x86_64-linux-android" ]]; then
    pushd "$BUNDLE_DIR" >/dev/null
      wget -q https://github.com/MrCyjaneK/monero_c/releases/download/v0.18.4.6-RC1/release-bundle.zip
      unzip -q release-bundle.zip && rm release-bundle.zip
    popd >/dev/null
  else echo "bundle already extracted"; fi

  step "stage jniLibs"
  declare -A ABI_MAP=(
    [aarch64-linux-android]=arm64-v8a
    [armv7a-linux-androideabi]=armeabi-v7a
    [x86_64-linux-android]=x86_64
  )
  for target in "${!ABI_MAP[@]}"; do
    abi="${ABI_MAP[$target]}"
    [[ -d "$BUNDLE_DIR/$target" ]] || { echo "SKIP $target"; continue; }
    mkdir -p "android/app/src/main/jniLibs/$abi"
    for coin in monero wownero; do
      src="$BUNDLE_DIR/$target/lib${coin}_wallet2_api_c.so"
      [[ -f "$src" ]] && cp -f "$src" "android/app/src/main/jniLibs/$abi/"
    done
  done
  find android/app/src/main/jniLibs -name "*.so" | sort

  step "reown yttrium uniffi bindings"
  # The prebuilt reown_flutter tarball that build-android.yml fetches does NOT
  # contain the generated Kotlin uniffi bindings. Without them, gradle dies
  # deep inside assembleDebug with a wall of
  #   e: ...Extensions.kt: Unresolved reference "uniffi"
  # which says nothing about the real cause.
  #
  # Upstream generates them in a SEPARATE image layer
  # (scripts/android/docker/Dockerfile.reown runs build_reown_deps.sh), which
  # the GitHub workflow never runs -- it assumes the runner already has them.
  # That is why the Gitea mac-mini runner builds green while a clean
  # replication of build-android.yml does not.
  if find scripts/reown_flutter -type d -name uniffi 2>/dev/null | grep -q .; then
    echo "uniffi bindings present"
  elif [[ -x scripts/android/build_reown_deps.sh ]]; then
    echo "uniffi bindings missing -- generating via build_reown_deps.sh"
    echo "(this needs the Rust/uniffi toolchain and is slow on a cold run)"
    # The prebuilt tarball unpacks a SHALLOW git repo. prepare_reown.sh then
    # does `git fetch -a && git checkout <pinned sha>`, which cannot reach that
    # commit through a shallow history and dies with
    #   fatal: unable to read tree (8a6d79ef...)
    # Unshallow in place rather than re-cloning: the tarball also carries
    # prebuilt native artifacts that a bare clone would not have.
    if [[ -d scripts/reown_flutter/.git ]] && \
       [[ "$(git -C scripts/reown_flutter rev-parse --is-shallow-repository)" == "true" ]]; then
      echo "unshallowing scripts/reown_flutter so the pinned commit is reachable"
      git -C scripts/reown_flutter fetch --unshallow --tags || \
        git -C scripts/reown_flutter fetch --depth=2147483647 --tags || true
    fi
    ./scripts/android/build_reown_deps.sh || {
      echo
      echo "FATAL: could not generate the reown uniffi bindings."
      echo "Options:"
      echo "  1. Build the upstream deps image: scripts/android/docker/build.sh"
      echo "  2. Use an APK from the Gitea runner, which already has them:"
      echo "     https://git.such.software/Builds/hash-wallet/actions"
      exit 1
    }
  else
    echo "FATAL: no uniffi bindings and no build_reown_deps.sh to generate them." >&2
    exit 1
  fi

  step "android configure (generates pubspec.yaml, manifest, app_properties)"
  pushd scripts/android >/dev/null
    source ./app_env.sh cakewallet
    ./app_config.sh
  popd >/dev/null
fi

step "local throwaway signing key"
# android/app/build.gradle wires the DEBUG build type to signingConfigs.release
# (see `debug { signingConfig signingConfigs.release }`). With no key.properties
# present, `file(null)` blows up gradle configuration before a single source
# file compiles -- so even a debug build needs a keystore.
#
# CI supplies the real Play upload key from secrets. Locally we mint a
# throwaway instead: a capture/demo APK must never be signed with the upload
# key, and this keeps that impossible by construction.
if [[ ! -f android/key.properties ]]; then
  keytool -genkeypair -v \
    -keystore android/app/debug-capture.jks \
    -storepass hashbags -keypass hashbags \
    -alias hashbags-debug \
    -keyalg RSA -keysize 2048 -validity 3650 \
    -dname "CN=Hash Bags Capture, OU=Demo, O=Such Software LLC, C=US" 2>/dev/null
  cat > android/key.properties <<EOF
storePassword=hashbags
keyPassword=hashbags
keyAlias=hashbags-debug
storeFile=debug-capture.jks
EOF
  echo "minted throwaway keystore android/app/debug-capture.jks (NOT the upload key)"
else
  echo "android/key.properties already present — leaving it alone"
fi

step "flutter pub get"
flutter pub get

step "generate secrets (empty defaults)"
# Real keys are injected by CI only. Locally these stay empty, which is the
# correct posture for a capture build: no live Trocador/MoonPay credentials
# end up in a demo APK.
[[ -f lib/.secrets.g.dart ]] && echo "secrets already generated" || dart run tool/generate_new_secrets.dart

step "codegen (mobx + hive adapters) -- this is the slow one"
bash model_generator.sh

step "localization"
dart run tool/generate_localization.dart

step "compile svg assets"
./compile_graphics.sh

step "build apk ($BUILD_MODE / ${TARGET_PLATFORM:-universal})"
# DEMO=1 bakes in DEMO_MODE so the app boots straight to an unlocked demo
# wallet (kDebugMode-gated, impossible in release). Lets capture skip the
# onboarding/PIN flow entirely.
# Use an ARRAY, not a string: the seed contains spaces (16 words), so a
# word-split string turns "--dart-define=DEMO_WALLET_SEED=word1 word2 ..."
# into separate argv tokens and flutter treats "unlock" as a target file
# ("Target file 'unlock' not found."). Array elements preserve the spaces.
DEMO_DEFINES=()
if [[ "${DEMO:-0}" == "1" ]]; then
  DEMO_DEFINES+=(--dart-define=DEMO_MODE=true "--dart-define=DEMO_PIN=${DEMO_PIN:-0801}")
  if [[ -n "${DEMO_WALLET_SEED:-}" ]]; then
    DEMO_DEFINES+=("--dart-define=DEMO_WALLET_SEED=${DEMO_WALLET_SEED}")
    DEMO_DEFINES+=("--dart-define=DEMO_WALLET_HEIGHT=${DEMO_WALLET_HEIGHT:-0}")
    echo "DEMO_MODE baked in (restore from seed, height ${DEMO_WALLET_HEIGHT:-0})"
  else
    echo "DEMO_MODE baked in (fresh wallet)"
  fi
fi
EXTRA_ARGS=()
[[ -n "$TARGET_PLATFORM" ]] && EXTRA_ARGS+=("--target-platform=$TARGET_PLATFORM")
flutter build apk --dart-define-from-file=env.json --$BUILD_MODE \
  "${EXTRA_ARGS[@]}" "${DEMO_DEFINES[@]+"${DEMO_DEFINES[@]}"}"

echo
echo "==> artifacts:"
ls -la build/app/outputs/flutter-apk/*.apk
'

# scripts/android/app_icon.sh points assets/images/app_logo.png at an ABSOLUTE
# path built from `pwd`, which inside the container is /work. That leaves a
# tracked file replaced by a symlink that dangles on the host and shows up as a
# typechange in `git status`. Put it back.
if [[ -L "$REPO_ROOT/assets/images/app_logo.png" ]]; then
  git -C "$REPO_ROOT" checkout -- assets/images/app_logo.png 2>/dev/null \
    && echo "restored assets/images/app_logo.png (container symlink removed)"
fi

echo
echo "Done. APK(s) under $REPO_ROOT/build/app/outputs/flutter-apk/"
