# Hash Bags — store screenshots

Three ways to produce the App Store / Play screenshots.

**Play (and all marketing video) runs on Linux** via the automated capture
harness — Path C, below. Only the **iOS** sets need macOS, because an iPhone/iPad
Simulator can't run on the Linux box.

## Required sizes (the Simulator outputs these exactly — don't hand-size)
| Store | Device to capture | Size | Count |
|---|---|---|---|
| App Store | **iPhone 16 Pro Max** (6.9") | 1290×2796 / 1320×2868 | 3–10 (required) |
| App Store | **iPad Pro 13" (M4)** | 2064×2752 | required *if* you ship iPad |
| Google Play | Pixel-class emulator | 1080×1920 (9:16) | 2–8 (required) |

---

## Path A — Manual (recommended for the first submission; ~15 min)
```bash
# iPhone
xcrun simctl boot "iPhone 16 Pro Max"; open -a Simulator
flutter run -d "iPhone 16 Pro Max"          # from repo root; navigate the app, then:
store/screenshot.sh 01-home
store/screenshot.sh 02-receive
store/screenshot.sh 03-send
store/screenshot.sh 04-swap
store/screenshot.sh 05-settings
# iPad — repeat booted on the iPad sim
xcrun simctl boot "iPad Pro 13-inch (M4)"
flutter run -d "iPad Pro 13-inch (M4)"
OUT_DIR=store/screenshots-ipad store/screenshot.sh 01-home   # ...etc

# Android (Play) — boot a Pixel emulator, run the app, then:
adb exec-out screencap -p > store/screenshots-play/01-home.png
```
`store/screenshot.sh` captures the booted simulator at the exact store size.

---

## Path B — Automated (fastlane snapshot; repeatable, multi-device/language)
Scaffolded here: `ios/fastlane/{Appfile,Snapfile,Fastfile}` +
`ios/RunnerUITests/HashBagsScreenshotsUITests.swift`.

**One-time setup (on the Mac):**
1. `cd ios && fastlane snapshot init` — drops `SnapshotHelper.swift` (matched to your fastlane version) into `ios/`. Move it into `ios/RunnerUITests/`.
2. In **Xcode** (`ios/Runner.xcworkspace`): File ▸ New ▸ Target ▸ **UI Testing Bundle**, name it **`RunnerUITests`**, target = `Runner`. Add `SnapshotHelper.swift` + `HashBagsScreenshotsUITests.swift` to it. Then edit the **Runner scheme ▸ Test** action and tick `RunnerUITests`.
3. **Screenshot-ready state:** wallet flows (create/PIN/seed/sync) are painful to drive, so make the app launch straight into a demo wallet when it sees the flag. In Dart, gate on `const bool.fromEnvironment('SCREENSHOT_MODE')` (or check `Platform.environment`/launch args): when true, restore a known demo wallet, skip onboarding, and stub balances. The UITest already passes `--dart-define=SCREENSHOT_MODE=true`.
4. **Accessibility:** the test taps by label/identifier. Add `Semantics(identifier: 'send_action')` (etc.) to the widgets you shoot, or rely on visible text ("Send", "Receive", "Swap", "Settings"). Tune the identifiers in the test.

**Run:**
```bash
cd ios && fastlane screenshots     # → ios/screenshots/en-US/<device>-01-Home.png ...
```

---

---

## Path C — Automated capture harness (Play + all video; runs on Linux)
`tools/demo/` drives the real app on a headless emulator while recording the
screen, then cuts one recording into **both** the screenshots and the video.
See `tools/demo/README.md`.

```bash
cp tools/demo/demo.env.example tools/demo/demo.env   # fill in; gitignored
export BW_SESSION=$(bw unlock --raw)                 # demo seed from Vaultwarden

tools/demo/build-apk.sh          # debug APK via the CI container (Flutter 3.32.0)
tools/demo/capture.sh boot       # creates/boots a 1080x1920 AVD
tools/demo/capture.sh all        # record all scenarios, cut, shoot, assemble
```

Why it exists, beyond convenience:
- **Sizing.** It builds its own AVD at exactly 1080×1920 (16:9). The stock
  "Medium Phone" AVD is 1080×2400 = **2.22:1**, which Play rejects (max 2:1).
- **Consistency.** Screenshots are frames of the same recording the trailer is
  cut from, taken at the timestamps the scenario reports.
- **Seed safety.** Frames containing a mnemonic are bracketed by the scenario
  and excised automatically; the tooling refuses to emit a publishable master
  if any clip wasn't verified. The demo wallet holds real funds.
- **Apple rules.** The `apple-preview` profile force-disables touch indicators,
  captions and music, and enforces Apple's 15–30s window.

Scenarios cover the core store set, onboarding/create, restore-from-seed, and
swap/buy.

---

## Upload
- **App Store Connect** ▸ your app ▸ version ▸ Previews and Screenshots → drag the 6.9" iPhone (and 13" iPad) sets.
- **Play Console** ▸ Store listing ▸ Phone screenshots → the 1080×1920 set; plus the **icon** (`store/play-icon-512.png`) and **feature graphic** (`store/play-feature-graphic-1024x500.png`).

> Reality check: for a *first* launch, Path A (manual) is faster. Path B pays off
> when you re-shoot across versions/locales. Either way it's a Mac task.
