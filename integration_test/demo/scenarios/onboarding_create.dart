import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../../components/common_test_flows.dart';
import '../../robots/dashboard_page_robot.dart';
import '../demo_config.dart';
import '../demo_session.dart';

/// ONBOARDING — first launch through to a live wallet.
///
/// The strongest marketing story the app has: no email, no KYC, no account,
/// wallet in under a minute.
///
/// SEED SAFETY: this flow generates a brand-new wallet, so a real mnemonic
/// WILL be rendered on the seed + verification screens. Those beats run inside
/// `blindfold`, which records the span into the driver output. `capture.sh`
/// refuses to promote a master to the publishable directory while any
/// blindfold span is uncut, so the frames cannot reach a store listing by
/// accident.
///
/// The wallet created here is throwaway. Never fund it.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('demo: onboarding + create wallet', (tester) async {
    FlutterError.onError = (FlutterErrorDetails details) {
      debugPrint('FlutterError caught: ${details.exception}');
    };

    final demo = DemoSession(tester, binding, 'onboarding_create');
    final flows = CommonTestFlows(tester);
    final dashboard = DashboardPageRobot(tester);

    demo.begin();

    await flows.startAppFlow(const ValueKey('demo_onboarding_create'));
    await demo.beat(3.0);
    await demo.hold(
      'welcome',
      caption: 'No email. No KYC. No account.',
      seconds: 3.5,
    );

    // The create flow walks PIN setup, seed display and seed verification in
    // one call. Everything from here until the dashboard is unsafe to publish.
    await demo.blindfold('new wallet seed is displayed and verified', () async {
      await flows.welcomePageToCreateNewWalletFlow(
        DemoConfig.walletType,
        DemoConfig.pin,
      );
    });

    await demo.beat(2.5);

    // Back on safe ground — verify it and shoot the payoff.
    await dashboard.isDashboardPage();
    demo.guardNoSeedOnScreen(because: 'post-create dashboard');
    await demo.hold(
      'wallet_ready',
      caption: 'A ${DemoConfig.walletLabel} wallet in under a minute',
      seconds: 4.0,
    );

    demo.finish();
  });
}
