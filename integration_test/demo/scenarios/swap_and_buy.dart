import 'package:cw_core/crypto_currency.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../../components/common_test_cases.dart';
import '../../components/common_test_flows.dart';
import '../../robots/dashboard_page_robot.dart';
import '../../robots/exchange_page_robot.dart';
import '../demo_config.dart';
import '../demo_session.dart';

/// SWAP + BUY — the exchange surface.
///
/// Shows a Trocador swap being configured and quoted. It deliberately stops
/// BEFORE `onExchangeButtonPressed()`: creating a trade moves real funds and
/// burns a real Trocador order, neither of which should happen to make a
/// marketing clip.
///
/// BUY is gated behind provider keys (see the MoonPay key-gating commit). A
/// capture build has empty secrets, so the Buy action is hidden and this
/// scenario logs that it skipped rather than failing — which is also the
/// correct store-review posture.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('demo: swap and buy', (tester) async {
    FlutterError.onError = (FlutterErrorDetails details) {
      debugPrint('FlutterError caught: ${details.exception}');
    };

    final demo = DemoSession(tester, binding, 'swap_and_buy');
    final flows = CommonTestFlows(tester);
    final cases = CommonTestCases(tester);
    final dashboard = DashboardPageRobot(tester);
    final exchange = ExchangePageRobot(tester);

    demo.begin();
    await flows.startAppFlow(const ValueKey('demo_swap_and_buy'));
    await demo.beat(3.0);

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

    await dashboard.isDashboardPage();
    await demo.beat(1.5);

    // ---------------- Swap --------------------------------------------
    await dashboard.navigateToExchangePage();
    await demo.beat(2.5);
    await exchange.isExchangePage();
    demo.guardNoSeedOnScreen(because: 'on exchange page');
    await demo.hold(
      'swap_open',
      caption: 'Swap without an account',
      seconds: 3.0,
    );

    await exchange.displayBothExchangeCards();
    await demo.beat(1.5);

    // Pick a pair. Wrapped because currency pickers are the most brittle part
    // of this screen — a picker change upstream should degrade the clip, not
    // kill the whole capture run.
    try {
      await exchange.selectDepositCurrency(CryptoCurrency.wow);
      await demo.beat(1.2);
      await exchange.selectReceiveCurrency(CryptoCurrency.btc);
      await demo.hold('pair_selected', caption: 'WOW → BTC', seconds: 2.5);

      await exchange.enterDepositAmount(DemoConfig.swapAmount);
      await demo.hold(
        'quote',
        caption: 'Live rate, no sign-up',
        seconds: 4.0,
      );
    } catch (e) {
      tester.printToConsole('[demo] swap pair selection degraded: $e');
      demo.mark('swap_pair_skipped');
    }

    // Stop here on purpose — no trade is created.
    demo.mark('swap_quoted_not_executed');
    await demo.beat(1.5);

    // ---------------- Buy (only if a provider is actually enabled) ------
    await cases.goBack();
    await demo.beat(1.5);

    final buyVisible = find.text('Buy').evaluate().isNotEmpty;
    if (buyVisible) {
      await dashboard.navigateToBuyPage();
      await demo.beat(2.5);
      demo.guardNoSeedOnScreen(because: 'on buy page');
      await demo.hold('buy', caption: 'Buy with card, where available', seconds: 3.5);
    } else {
      tester.printToConsole(
        '[demo] Buy is hidden — no provider key in this build. Skipping, '
        'which matches what store reviewers will see.',
      );
      demo.mark('buy_hidden_no_provider');
    }

    demo.finish();
  });
}
