import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../../components/common_test_cases.dart';
import '../../components/common_test_flows.dart';
import '../../robots/dashboard_page_robot.dart';
import '../../robots/send_page_robot.dart';
import '../demo_config.dart';
import '../demo_session.dart';

/// CORE STORE SET — the screens that become App Store / Play screenshots and
/// the backbone of the marketing reel.
///
/// Dashboard → Receive → Send (composed, never broadcast) → Wallets → Security.
///
/// If the device already holds the demo wallet, this shoots it directly. If it
/// does not, the scenario restores from seed first — slower, and the restore
/// frames get excised as a blindfold span, but the footage is still correct.
///
/// NOTHING here broadcasts a transaction. The Send screen is filled in and
/// held on the review step so the UI is fully populated, then backed out of.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('demo: core store set', (tester) async {
    FlutterError.onError = (FlutterErrorDetails details) {
      debugPrint('FlutterError caught: ${details.exception}');
    };

    final demo = DemoSession(tester, binding, 'core_store_set');
    final flows = CommonTestFlows(tester);
    final cases = CommonTestCases(tester);
    final dashboard = DashboardPageRobot(tester);
    final send = SendPageRobot(tester: tester);

    demo.begin();
    await flows.startAppFlow(const ValueKey('demo_core_store_set'));
    await demo.beat(3.0);

    // If the device was not pre-seeded with the demo wallet, restore it now.
    // The seed screens are bracketed so the frames can be cut.
    if (DemoConfig.hasSeed && find.text('Restore').evaluate().isNotEmpty) {
      await demo.blindfold('restoring demo wallet from seed', () async {
        await flows.welcomePageToRestoreWalletThroughSeedsFlow(
          DemoConfig.walletType,
          DemoConfig.walletSeed,
          DemoConfig.pin,
        );
      });
      await demo.beat(2.0);
    }

    // ---------------- 1. Dashboard ------------------------------------
    await dashboard.isDashboardPage();
    demo.guardNoSeedOnScreen(because: 'on dashboard');
    await demo.hold(
      'dashboard',
      caption: 'Your keys. Your coins.',
      seconds: 3.5,
    );

    // ---------------- 2. Receive --------------------------------------
    await dashboard.navigateToReceivePage();
    await demo.beat(2.0);
    demo.guardNoSeedOnScreen(because: 'on receive page');
    await demo.hold(
      'receive',
      caption: 'Receive in a tap',
      seconds: 4.0,
    );
    await cases.goBack();
    await demo.beat(1.5);

    // ---------------- 3. Send (compose only) --------------------------
    await dashboard.navigateToSendPage();
    await send.checkIfSendPageIsVisible();
    await demo.beat(1.2);
    demo.mark('send_open', caption: 'Send with confidence');

    if (DemoConfig.sendToAddress.isNotEmpty) {
      // Typed at human speed — an instant fill reads as a paste on camera.
      final addressField = find.byType(EditableText).first;
      await demo.typeSlowly(addressField, DemoConfig.sendToAddress);
      demo.mark('send_address_entered');
    }
    await demo.beat(1.0);
    await send.enterSendAmount(DemoConfig.sendAmount);
    await demo.hold('send_amount_entered', seconds: 2.5);

    // Deliberately NOT calling onSendButtonPressed(). We show a fully
    // composed transaction and walk away — no funds move to make a video.
    demo.mark('send_composed_not_broadcast');
    await cases.goBack();
    await demo.beat(1.5);

    // ---------------- 4. Wallet list ----------------------------------
    await dashboard.navigateToWalletsListPage();
    await demo.beat(2.0);
    demo.guardNoSeedOnScreen(because: 'on wallet list');
    await demo.hold(
      'wallets',
      caption: 'Wownero, Monero, Bitcoin & more',
      seconds: 3.5,
    );
    await cases.goBack();
    await demo.beat(1.5);

    // ---------------- 5. Security & backup ----------------------------
    await dashboard.openDrawerMenu();
    await demo.beat(2.0);
    await demo.hold(
      'menu',
      caption: 'Everything under your control',
      seconds: 3.0,
    );
    demo.guardNoSeedOnScreen(because: 'in drawer menu');

    demo.finish();
  });
}
