# Hash Bags capture harness

Drives the real app through real wallet flows on an emulator while recording
the screen, then cuts the recording into store screenshots and marketing video.

One recording produces **both** deliverables. Screenshots are pulled from the
same footage as the video, at the timestamps the scenario reports, so a listing
can't drift out of sync with its own trailer.

```
integration_test/demo/scenarios/*.dart   drive the app, emit timing marks
        │
        ▼
tools/demo/capture.sh record <scenario>  adb screenrecord + flutter drive
        │
        ├── marks.py cut    → trims lead-in, EXCISES seed frames
        ├── marks.py shots  → store screenshots at native 1080x1920
        └── reel.py         → branded master (social / apple-preview / play)
```

## Quick start

```bash
cp tools/demo/demo.env.example tools/demo/demo.env   # fill in, gitignored
export BW_SESSION=$(bw unlock --raw)                 # Vaultwarden

tools/demo/build-apk.sh          # optional but recommended — see below
tools/demo/capture.sh boot       # 1080x1920 headless AVD
tools/demo/capture.sh all        # record every scenario + assemble a reel
```

`build-apk.sh` is **not** a strict prerequisite — `capture.sh record` runs
`flutter drive`, which builds its own instrumented debug APK. Run it first
anyway on a fresh checkout: it validates the entire toolchain in one shot,
mints the local signing key, and warms the Gradle cache, so your first `record`
doesn't spend twenty minutes compiling only to hit a config error. It also
leaves you a sideloadable APK.

Individual steps:

```bash
tools/demo/capture.sh record core_store_set
tools/demo/capture.sh shots  core_store_set
tools/demo/capture.sh reel   social
tools/demo/capture.sh reel   apple-preview --overlays none
```

Output lands in `~/Build/hash-wallet/demo/` (never in the repo), split into
`raw/`, `cut/`, `screenshots/` and `publish/`.

## Scenarios

| Scenario | Shows | Notes |
|---|---|---|
| `core_store_set` | Dashboard, Receive, Send, Wallets, Security | The store screenshot set. Send is **composed, never broadcast**. |
| `onboarding_create` | Welcome → PIN → seed → dashboard | Creates a throwaway wallet. Never fund it. |
| `restore_from_seed` | Restore from mnemonic → syncing | Uses the demo wallet seed. |
| `swap_and_buy` | Trocador swap quote, Buy | Stops **before** creating a trade. Buy is skipped when no provider key is present. |

Scenarios reuse the existing page robots in `integration_test/robots/`. They
are not correctness tests — they add pacing (`beat`, `hold`, `typeSlowly`) so
the footage is watchable, and timing marks so captions land on the right frame.

## Seed safety

The demo wallet is a **real wallet with a real balance** — that is what makes
the screenshots honest, and it is also why the harness is paranoid:

- The seed lives in Vaultwarden. It is fetched at capture time into one shell
  variable and passed as a `--dart-define`. It is never written to the repo,
  to `.secrets.g.dart`, or to `demo.env`.
- `DemoSession.guardNoSeedOnScreen()` fails the run if a mnemonic is rendered
  while recording. It checks for the known demo seed (whole and word-scattered)
  *and* for the generic shape of a mnemonic, so a freshly generated seed is
  caught too.
- Flows that must pass through a seed screen wrap it in `blindfold()`. Those
  spans are reported to the host and **excised from the video**, padded by
  0.6s on each side. Screenshots use the same padding.
- `marks.py manifest` **refuses** to build a publishable master if any clip was
  cut without marks, since blindfold spans could not have been excised.

Do not lift those guards to get a nicer shot.

## Overlays and the Apple App Preview

Touch indicators are the system-level ripple (`settings put system
show_touches 1`), not a composited fake cursor — so they appear in the
recording exactly as a user would see them.

They are **on by default**, and **force-disabled for `apple-preview`**.
`capture.sh reel apple-preview` refuses to run against footage recorded with
`--overlays taps`. The App Preview shows the app as-is: no touch indicators,
no captions, no title/CTA cards, no music bed. `reel.py` also enforces
Apple's 15–30s duration window and will fail rather than emit an out-of-spec
preview.

## The capture AVD (both details matter)

Create it as **API 35**, at exactly **1080×1920**:

```bash
avdmanager create avd -n HashBags_Capture \
  -k "system-images;android-35;google_apis;x86_64" -d pixel_6
# then in ~/.android/avd/HashBags_Capture.avd/config.ini:
#   hw.lcd.width=1080  hw.lcd.height=1920  hw.lcd.density=420
#   hw.ramSize=6144    showDeviceFrame=no
```

**Size:** the stock "Medium Phone" AVD is 1080×2400 = **2.22:1**, and Play
rejects phone screenshots above **2:1**. `marks.py shots` warns if extracted
frames violate that ratio.

**API level:** use 35, not 36. On the API 36.1 image the guest MediaCodec AVC
encoder is broken — `screenrecord` fails with `Encoder failed (err=-38)` at
every resolution and writes a 0-byte file, and `screencap` aborts on a
SwiftShader DMA assertion. Verified broken under `swiftshader_indirect` *and*
under `-gpu host` on a real NVIDIA GPU. API 35 + `-gpu software`
+ `-feature -Vulkan` (what `capture.sh boot` uses) works.

iOS App Store screenshots and the App Preview still have to come from a Mac —
see `store/SCREENSHOTS.md` for the fastlane snapshot path.

## Why a container for the build

The repo pins Flutter 3.32.0. A host Flutter 3.38+ **cannot resolve the
dependency set at all** — `hive_generator` wants an analyzer that still ships
the `macros` package, which newer Dart SDKs removed. `build-apk.sh` therefore
builds inside the same image CI uses.

It also mints a **throwaway** signing key: `android/app/build.gradle` wires the
debug build type to `signingConfigs.release`, so a local build cannot even
configure without a keystore. A capture APK must never be signed with the Play
upload key, and minting a separate one keeps that impossible by construction.

## Reusing this elsewhere

`reel.py` imports `such_graphics.video_transitions` (tuned xfade presets) and
`such_graphics.video_qa` (decode-level "did this render black" gate) from
`~/src/such-graphics` when that repo is checked out, and falls back to a local
subset when it is not — this repo is public and must build without it. Point
`SUCH_GRAPHICS_HOME` elsewhere if needed.

The music-bed handling (random offset per render, so repeat uploads of the same
variant don't feel identical) is lifted from
`~/src/medusa-multi-tenant-platform/tools/marketing-video/build.mjs`.
