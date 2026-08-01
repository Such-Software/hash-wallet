import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../../components/common_test_flows.dart';
import '../../robots/dashboard_page_robot.dart';
import '../demo_config.dart';
import '../demo_session.dart';

/// RESTORE — bring an existing wallet back from its seed.
///
/// The "you are not locked in" story: the seed is yours, the wallet is
/// portable, Hash Bags is just a viewer for keys you already hold.
///
/// SEED SAFETY: the entry screen necessarily shows the demo wallet's real
/// mnemonic, so the whole restore is wrapped in `blindfold`. The publishable
/// cut starts at the dashboard. Do not lift that bracket to "get a better
/// shot" — the demo wallet holds real funds.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('demo: restore from seed', (tester) async {
    FlutterError.onError = (FlutterErrorDetails details) {
      debugPrint('FlutterError caught: ${details.exception}');
    };

    final demo = DemoSession(tester, binding, 'restore_from_seed');
    final flows = CommonTestFlows(tester);
    final dashboard = DashboardPageRobot(tester);

    if (!DemoConfig.hasSeed) {
      fail('restore_from_seed needs DEMO_WALLET_SEED. Run it through '
          'tools/demo/capture.sh, which pulls the seed from Vaultwarden.');
    }

    demo.begin();

    await flows.startAppFlow(const ValueKey('demo_restore_from_seed'));
    await demo.beat(3.0);
    await demo.hold(
      'welcome',
      caption: 'Already have a wallet?',
      seconds: 3.0,
    );

    await demo.blindfold('demo wallet mnemonic is typed on screen', () async {
      await flows.welcomePageToRestoreWalletThroughSeedsFlow(
        DemoConfig.walletType,
        DemoConfig.walletSeed,
        DemoConfig.pin,
      );
    });

    await demo.beat(3.0);

    await dashboard.isDashboardPage();
    demo.guardNoSeedOnScreen(because: 'post-restore dashboard');
    await demo.hold(
      'restored',
      caption: 'Your seed. Your wallet. Anywhere.',
      seconds: 4.0,
    );

    // Let the sync indicator run a little — real syncing is part of the story
    // and it looks alive on camera.
    await demo.hold('syncing', caption: 'Syncing from the network', seconds: 4.0);

    demo.finish();
  });
}
