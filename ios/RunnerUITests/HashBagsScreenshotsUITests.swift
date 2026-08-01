import XCTest

// fastlane snapshot UI test for Hash Bags.
//
// IMPORTANT — Flutter caveat: Flutter renders the whole UI into ONE native view.
// XCUITest finds "elements" only through the ACCESSIBILITY tree. So for taps to
// work you must either (a) match by the visible label text, or (b) add
// Semantics(identifier: 'send_button') around the widgets you drive. Wallet flows
// (create/restore, PIN) are painful to automate, so the recommended pattern is to
// launch straight into a screenshot-ready DEMO wallet via a launch argument that
// the Flutter app recognizes (see store/SCREENSHOTS.md), then shoot the key
// screens. Adjust identifiers/waits to match the actual UI.
final class HashBagsScreenshotsUITests: XCTestCase {

  var app: XCUIApplication!

  override func setUpWithError() throws {
    continueAfterFailure = false
    app = XCUIApplication()
    setupSnapshot(app)                       // from SnapshotHelper.swift (fastlane snapshot init)
    // Tell the Flutter app to restore a demo wallet + skip onboarding so the
    // shots show a real dashboard. Handle this arg in Dart (see the guide).
    app.launchArguments += ["--dart-define=SCREENSHOT_MODE=true", "FASTLANE_SNAPSHOT"]
    app.launch()
  }

  func testScreenshots() throws {
    // 1) Home / dashboard — wait for it to settle, then shoot.
    _ = app.otherElements["home_dashboard"].waitForExistence(timeout: 45)
    snapshot("01-Home")

    // 2) Receive
    tapFirst(["Receive", "receive_action"])
    snapshot("02-Receive")
    goBack()

    // 3) Send
    tapFirst(["Send", "send_action"])
    snapshot("03-Send")
    goBack()

    // 4) Swap (Trocador)
    tapFirst(["Swap", "exchange_action"])
    snapshot("04-Swap")
    goBack()

    // 5) Settings
    tapFirst(["Settings", "settings_action"])
    snapshot("05-Settings")
  }

  // MARK: - helpers

  /// Tap the first element (button or generic) matching any of the given
  /// accessibility labels/identifiers.
  private func tapFirst(_ names: [String], timeout: TimeInterval = 15) {
    for n in names {
      let btn = app.buttons[n]
      if btn.waitForExistence(timeout: 2) { btn.tap(); return }
      let any = app.descendants(matching: .any)[n]
      if any.exists { any.tap(); return }
    }
    XCTFail("Could not find any of: \(names). Add a Semantics(identifier:) to that widget.")
  }

  private func goBack() {
    let back = app.navigationBars.buttons.element(boundBy: 0)
    if back.waitForExistence(timeout: 3) { back.tap() }
  }
}
