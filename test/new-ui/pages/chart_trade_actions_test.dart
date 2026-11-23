import 'package:cw_core/balance.dart';
import 'package:cw_core/crypto_currency.dart';
import 'package:cw_core/transaction_history.dart';
import 'package:cw_core/transaction_info.dart';
import 'package:cw_core/wallet_base.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hash_wallet/di.dart';
import 'package:hash_wallet/generated/i18n.dart';
import 'package:hash_wallet/locales/locale.dart';
import 'package:hash_wallet/new-ui/viewmodels/charts/charts_bloc.dart';
import 'package:hash_wallet/new-ui/widgets/charts_page/chart_modal.dart';
import 'package:hash_wallet/store/app_store.dart';
import 'package:hash_wallet/themes/core/theme_store.dart';
import 'package:mobx/mobx.dart' show ObservableMap;
import 'package:mocktail/mocktail.dart';

class _MockAppStore extends Mock implements AppStore {}

class _MockWallet extends Mock
    implements WalletBase<Balance, TransactionHistoryBase<TransactionInfo>, TransactionInfo> {}

class _MockBalance extends Mock implements Balance {}

class _MockChartsBloc extends Mock implements ChartsBloc {}

void main() {
  testWidgets('Chart actions offer swaps without advertising an unavailable off-ramp',
      (tester) async {
    final appStore = _MockAppStore();
    final wallet = _MockWallet();
    when(() => appStore.wallet).thenReturn(wallet);
    when(() => wallet.balance).thenReturn(ObservableMap.of({CryptoCurrency.btc: _MockBalance()}));
    final bloc = _MockChartsBloc();
    when(() => bloc.state).thenReturn(const ChartsInitial());
    when(() => bloc.stream).thenAnswer((_) => const Stream<ChartsState>.empty());
    getIt.registerSingleton<AppStore>(appStore);
    getIt.registerSingleton(ThemeStore());
    addTearDown(() async {
      await getIt.unregister<ThemeStore>();
      await getIt.unregister<AppStore>();
    });

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: localizationDelegates,
        supportedLocales: S.delegate.supportedLocales,
        home: Scaffold(
          body: ChartModal(bloc: bloc, currency: CryptoCurrency.btc, isFavorite: false),
        ),
      ),
    );
    await tester.pump();

    expect(find.text(S.current.swap), findsOneWidget);
    expect(find.text(S.current.sell), findsNothing);
  });
}
