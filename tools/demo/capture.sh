#!/usr/bin/env bash
# Hash Bags capture harness — drive real wallet flows while recording screen.
#
# One recording produces BOTH deliverables: the video (trimmed and captioned
# from the scenario's timing marks) and the store screenshots (frames pulled at
# those same marks, at native device resolution). Shooting them separately is
# how listings end up inconsistent.
#
#   tools/demo/capture.sh boot
#   tools/demo/capture.sh record core_store_set
#   tools/demo/capture.sh shots  core_store_set
#   tools/demo/capture.sh reel   social
#   tools/demo/capture.sh all
#
# Options:
#   --target android|linux    where to run       (default: android)
#   --overlays taps|none      touch indicators   (default: taps)
#   --avd NAME                emulator AVD       (default: HashBags_Capture)
#   --serial NAME             adb serial         (default: autodetect)
#
# OVERLAYS AND THE APPLE APP PREVIEW
#   The `apple-preview` reel profile force-disables overlays and refuses to run
#   with --overlays=taps. The App Preview must be the app as a user sees it,
#   with no synthetic touch indicators composited on top. Everything else
#   (social cuts, Play listing video, docs GIFs) keeps taps on by default,
#   because there they genuinely help a viewer follow the interaction.
#
# SEED SAFETY
#   Scenarios bracket every frame containing a mnemonic in a `blindfold` span
#   and report those spans back through the driver. This script refuses to
#   promote any master to the publishable directory while a blindfold span is
#   still inside the cut. The demo wallet holds real funds — that guard is not
#   optional and should not be edited out.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
# shellcheck source=lib/secrets.sh
source "$HERE/lib/secrets.sh"
demo_load_env "$HERE/demo.env"

IMAGE="${CI_IMAGE:-ghcr.io/cake-tech/cake_wallet:debian13-flutter3.32.0-ndkr28-go1.24.1-ruststablenightly}"
ANDROID_SDK="${ANDROID_HOME:-$HOME/Android/Sdk}"
ADB="$ANDROID_SDK/platform-tools/adb"
EMULATOR_BIN="$ANDROID_SDK/emulator/emulator"

TARGET="android"
OVERLAYS="taps"
AVD="${DEMO_AVD:-HashBags_Capture}"
SERIAL="${DEMO_SERIAL:-}"

# Build outputs live outside the repo, per the workstation conventions.
OUT_ROOT="${DEMO_OUT_ROOT:-$HOME/Build/hash-wallet/demo}"
RAW_DIR="$OUT_ROOT/raw"          # untrimmed recordings + driver JSON
CUT_DIR="$OUT_ROOT/cut"          # trimmed, blindfold-free clips
SHOT_DIR="$OUT_ROOT/screenshots" # store screenshots
PUB_DIR="$OUT_ROOT/publish"      # finished masters — only safe material lands here

SCENARIOS=(core_store_set onboarding_create restore_from_seed swap_and_buy)

# On-device path for the in-flight recording.
DEV_CAPTURE=/data/local/tmp/hb-capture.mp4

log()  { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[warn]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[fail]\033[0m %s\n' "$*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# arg parsing
# ---------------------------------------------------------------------------
CMD="${1:-help}"; shift || true
POSITIONAL=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)   TARGET="$2"; shift 2 ;;
    --overlays) OVERLAYS="$2"; shift 2 ;;
    --avd)      AVD="$2"; shift 2 ;;
    --serial)   SERIAL="$2"; shift 2 ;;
    -h|--help)  CMD="help"; shift ;;
    *)          POSITIONAL+=("$1"); shift ;;
  esac
done
set -- "${POSITIONAL[@]+"${POSITIONAL[@]}"}"

# ---------------------------------------------------------------------------
# device helpers
# ---------------------------------------------------------------------------
# Wait up to `timeout` seconds for a device to appear. A freshly launched
# emulator takes appreciably longer than a fixed sleep to register with adb,
# and the port varies (5554, 5556, ...) depending on what else is running.
detect_serial() {
  [[ -n "$SERIAL" ]] && return 0
  local timeout="${1:-90}" waited=0
  while (( waited < timeout )); do
    SERIAL="$("$ADB" devices | awk '$2=="device" {print $1; exit}')"
    [[ -n "$SERIAL" ]] && { log "device: $SERIAL"; return 0; }
    sleep 2; waited=$((waited + 2))
  done
  die "no device appeared within ${timeout}s. Run: tools/demo/capture.sh boot"
}

adbs() { "$ADB" -s "$SERIAL" "$@"; }

wait_for_boot() {
  log "waiting for device boot"
  "$ADB" -s "$SERIAL" wait-for-device
  local tries=0
  until [[ "$("$ADB" -s "$SERIAL" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" == "1" ]]; do
    ((tries++)); [[ $tries -gt 180 ]] && die "device did not finish booting"
    sleep 2
  done
  log "device booted ($SERIAL)"
}

cmd_boot() {
  if "$ADB" devices | grep -q "device$"; then
    log "a device is already booted"; detect_serial; return 0
  fi
  log "booting AVD $AVD (headless)"
  # -feature -GLDMA: with swiftshader_indirect on a headless host, the guest
  # graphics stack otherwise aborts on
  #   "Assertion failed: !rcEnc->featureInfo()->hasReadColorBufferDma"
  # which kills screencap and screenrecord — i.e. exactly the two things this
  # harness needs. Disabling the DMA colour-buffer path costs a little capture
  # throughput and makes both work.
  nohup "$EMULATOR_BIN" -avd "$AVD" -no-window -no-audio -no-boot-anim \
    -gpu swiftshader_indirect -feature -GLDMA -no-snapshot-save \
    > "$OUT_ROOT/emulator.log" 2>&1 &
  sleep 5
  detect_serial
  wait_for_boot
}

set_overlays() {
  # Native touch indicators. Far cleaner than compositing a fake cursor: this
  # is the real system-level ripple, drawn by SurfaceFlinger, so it appears in
  # screenrecord exactly as a user would see it.
  local on="$1"
  if [[ "$on" == "taps" ]]; then
    log "touch indicators ON"
    adbs shell settings put system show_touches 1 || true
    adbs shell settings put system pointer_location 0 || true
  else
    log "touch indicators OFF"
    adbs shell settings put system show_touches 0 || true
    adbs shell settings put system pointer_location 0 || true
  fi
}

prep_device_for_camera() {
  # A clean status bar. Google's own demo-mode API — no root needed.
  adbs shell settings put global sysui_demo_allowed 1 || true
  adbs shell am broadcast -a com.android.systemui.demo -e command enter >/dev/null 2>&1 || true
  adbs shell am broadcast -a com.android.systemui.demo -e command clock -e hhmm 0941 >/dev/null 2>&1 || true
  adbs shell am broadcast -a com.android.systemui.demo -e command battery -e level 100 -e plugged false >/dev/null 2>&1 || true
  adbs shell am broadcast -a com.android.systemui.demo -e command network -e wifi show -e level 4 >/dev/null 2>&1 || true
  adbs shell am broadcast -a com.android.systemui.demo -e command network -e mobile show -e datatype none -e level 4 >/dev/null 2>&1 || true
  adbs shell am broadcast -a com.android.systemui.demo -e command notifications -e visible false >/dev/null 2>&1 || true
  # Kill animations-off if a previous test run set them; we WANT animations.
  adbs shell settings put global window_animation_scale 1 || true
  adbs shell settings put global transition_animation_scale 1 || true
  adbs shell settings put global animator_duration_scale 1 || true
}

exit_demo_mode() {
  adbs shell am broadcast -a com.android.systemui.demo -e command exit >/dev/null 2>&1 || true
}

# ---------------------------------------------------------------------------
# record
# ---------------------------------------------------------------------------
cmd_record() {
  local scenario="${1:-}"
  [[ -n "$scenario" ]] || die "usage: capture.sh record <scenario>  (${SCENARIOS[*]})"
  [[ -f "$REPO_ROOT/integration_test/demo/scenarios/$scenario.dart" ]] \
    || die "no such scenario: $scenario"

  mkdir -p "$RAW_DIR"
  detect_serial
  wait_for_boot
  set_overlays "$OVERLAYS"
  prep_device_for_camera

  # Pull the demo seed only if the scenario needs it.
  local seed=""
  if [[ "$scenario" != "onboarding_create" ]]; then
    if seed="$(demo_secret seed 2>/dev/null)"; then
      log "demo wallet seed loaded from Vaultwarden ($(echo "$seed" | wc -w) words)"
    else
      warn "no demo seed available — scenario will run against whatever wallet the device already has"
      seed=""
    fi
  fi
  local send_addr="${DEMO_SEND_ADDRESS:-}"

  local dev_epoch_start
  dev_epoch_start="$(adbs shell date +%s%3N | tr -d '\r')"

  log "starting screenrecord"
  # /data/local/tmp, not /sdcard: the emulator's emulated-storage FUSE layer
  # is flaky headless ("Transport endpoint is not connected"), and screenrecord
  # then fails to open its output. /data/local/tmp is a plain filesystem that
  # adb can always read and write.
  adbs shell rm -f "$DEV_CAPTURE" || true
  adbs shell screenrecord --size 1080x1920 --bit-rate 12000000 \
    --time-limit 180 "$DEV_CAPTURE" &
  local rec_pid=$!
  sleep 2   # let the encoder actually start before the app launches

  log "driving scenario: $scenario"
  set +e
  docker run --rm --network host \
    -v "$REPO_ROOT":/work -w /work \
    -e HOST_UID="$(id -u)" -e HOST_GID="$(id -g)" \
    -e DEMO_SEED="$seed" -e DEMO_SEND_ADDR="$send_addr" \
    -e SCENARIO="$scenario" -e SERIAL="$SERIAL" \
    "$IMAGE" bash -c '
      trap "chown -R ${HOST_UID}:${HOST_GID} /work 2>/dev/null || true" EXIT
      git config --global --add safe.directory "*"
      flutter drive \
        --driver=test_driver/integration_test.dart \
        --target=integration_test/demo/scenarios/'"$scenario"'.dart \
        -d "$SERIAL" \
        --dart-define-from-file=env.json \
        --dart-define=DEMO_WALLET_SEED="$DEMO_SEED" \
        --dart-define=DEMO_SEND_ADDRESS="$DEMO_SEND_ADDR"
    ' 2>&1 | tee "$RAW_DIR/$scenario.drive.log"
  local drive_rc=${PIPESTATUS[0]}
  set -e

  log "stopping screenrecord"
  adbs shell pkill -INT screenrecord || true
  wait "$rec_pid" 2>/dev/null || true
  sleep 3   # screenrecord needs a moment to finalise the moov atom

  adbs pull "$DEV_CAPTURE" "$RAW_DIR/$scenario.mp4" >/dev/null \
    || die "could not pull recording — did screenrecord start?"
  adbs shell rm -f "$DEV_CAPTURE" || true

  # Driver output: marks + blindfold spans.
  if [[ -f "$REPO_ROOT/integration_test/integration_response_data.json" ]]; then
    cp "$REPO_ROOT/integration_test/integration_response_data.json" \
       "$RAW_DIR/$scenario.marks.json"
  else
    warn "no driver output — captions and screenshots will be unavailable"
  fi
  echo "$dev_epoch_start" > "$RAW_DIR/$scenario.recstart"

  exit_demo_mode
  if [[ $drive_rc -ne 0 ]]; then
    warn "scenario exited non-zero ($drive_rc); the recording was still saved."
    warn "check $RAW_DIR/$scenario.drive.log"
  fi
  log "raw recording: $RAW_DIR/$scenario.mp4"
  cmd_cut "$scenario"
}

# ---------------------------------------------------------------------------
# cut — trim launch/install lead-in and excise every blindfold span
# ---------------------------------------------------------------------------
cmd_cut() {
  local scenario="${1:-}"
  [[ -n "$scenario" ]] || die "usage: capture.sh cut <scenario>"
  local raw="$RAW_DIR/$scenario.mp4"
  [[ -f "$raw" ]] || die "no raw recording for $scenario"
  mkdir -p "$CUT_DIR"

  python3 "$HERE/marks.py" cut \
    --raw "$raw" \
    --marks "$RAW_DIR/$scenario.marks.json" \
    --recstart "$RAW_DIR/$scenario.recstart" \
    --out "$CUT_DIR/$scenario.mp4" \
    --manifest "$CUT_DIR/$scenario.manifest.json"
  log "cut clip: $CUT_DIR/$scenario.mp4"
}

# ---------------------------------------------------------------------------
# shots — store screenshots pulled from the recording at mark timestamps
# ---------------------------------------------------------------------------
cmd_shots() {
  local scenario="${1:-}"
  [[ -n "$scenario" ]] || die "usage: capture.sh shots <scenario>"
  mkdir -p "$SHOT_DIR"
  python3 "$HERE/marks.py" shots \
    --raw "$RAW_DIR/$scenario.mp4" \
    --marks "$RAW_DIR/$scenario.marks.json" \
    --recstart "$RAW_DIR/$scenario.recstart" \
    --outdir "$SHOT_DIR"
  log "screenshots: $SHOT_DIR"
}

# ---------------------------------------------------------------------------
# reel — assemble a finished master
# ---------------------------------------------------------------------------
cmd_reel() {
  local profile="${1:-social}"
  mkdir -p "$PUB_DIR"

  if [[ "$profile" == "apple-preview" && "$OVERLAYS" == "taps" ]]; then
    die "apple-preview requires --overlays none. Re-record with:
    tools/demo/capture.sh record <scenario> --overlays none
An App Preview must show the app as-is, without composited touch indicators."
  fi

  local manifest="$PUB_DIR/$profile.manifest.json"
  local music_args=()
  # apple-preview ignores music by design; reel.py enforces that too.
  if [[ -n "${DEMO_MUSIC:-}" && "$profile" != "apple-preview" ]]; then
    if [[ -f "$DEMO_MUSIC" ]]; then
      music_args=(--music "$DEMO_MUSIC")
    else
      warn "DEMO_MUSIC set but not found: $DEMO_MUSIC — rendering silent"
    fi
  fi
  python3 "$HERE/marks.py" manifest \
    --cutdir "$CUT_DIR" --profile "$profile" --out "$manifest" \
    --scenarios "${SCENARIOS[*]}" "${music_args[@]+"${music_args[@]}"}"

  python3 "$HERE/reel.py" \
    --manifest "$manifest" --profile "$profile" \
    -o "$PUB_DIR/hashbags-$profile.mp4"
  log "master: $PUB_DIR/hashbags-$profile.mp4"
}

cmd_all() {
  cmd_boot
  for s in "${SCENARIOS[@]}"; do
    cmd_record "$s" || warn "scenario $s failed; continuing"
    cmd_shots "$s"  || warn "shots for $s failed; continuing"
  done
  cmd_reel social
  log "done. publishable output under $PUB_DIR"
}

cmd_help() { sed -n '2,40p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }

mkdir -p "$OUT_ROOT"

if [[ "$TARGET" == "linux" ]]; then
  die "--target linux is not implemented.

The Linux desktop build DOES render the phone UI (linux/my_application.cc
forces a 720x1280 window when DESKTOP_FORCE_MOBILE is set), and Xvfb +
ffmpeg x11grab are available on this box, so it is a reasonable fast-iteration
path. What it needs first:
  1. ./configure_hash_wallet.sh linux  (builds the x86_64-linux-gnu monero_c libs)
  2. a recorder branch here using: Xvfb :99 + DESKTOP_FORCE_MOBILE=Y
     flutter drive -d linux + ffmpeg -f x11grab -video_size 720x1280 -i :99

It is deliberately NOT wired up half-way: desktop chrome, fonts and insets
differ from the phone build, so Linux footage must never be used for a store
listing. Use --target android for anything shippable."
elif [[ "$TARGET" != "android" ]]; then
  die "--target must be 'android' (see help)"
fi

case "$CMD" in
  boot)  cmd_boot ;;
  record) cmd_record "${1:-}" ;;
  cut)   cmd_cut "${1:-}" ;;
  shots) cmd_shots "${1:-}" ;;
  reel)  cmd_reel "${1:-social}" ;;
  all)   cmd_all ;;
  help|*) cmd_help ;;
esac
