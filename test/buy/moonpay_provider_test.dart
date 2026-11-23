import 'package:cw_core/balance.dart';
import 'package:cw_core/crypto_currency.dart';
import 'package:cw_core/transaction_history.dart';
import 'package:cw_core/transaction_info.dart';
import 'package:cw_core/wallet_base.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hash_wallet/buy/moonpay/moonpay_payment_methods.dart';
import 'package:hash_wallet/buy/moonpay/moonpay_provider.dart';
import 'package:hash_wallet/buy/payment_method.dart';
import 'package:hash_wallet/store/app_store.dart';
import 'package:mocktail/mocktail.dart';

class _MockAppStore extends Mock implements AppStore {}

class _MockWallet extends Mock
    implements WalletBase<Balance, TransactionHistoryBase<TransactionInfo>, TransactionInfo> {}

class _MoonPayProvider extends MoonPayProvider {
  _MoonPayProvider(this.lookup) : super(appStore: _MockAppStore(), wallet: _MockWallet());

  final Future<List<MoonPayPaymentMethod>> Function() lookup;

  @override
  Future<List<MoonPayPaymentMethod>> fetchMoonPayPaymentMethods({
    required String currencyCode,
    String transactionType = 'buy',
  }) =>
      lookup();
}

void main() {
  test('MoonPay can quote a buy without a method filter when lookup fails', () async {
    final provider = _MoonPayProvider(() async => throw StateError('Lookup unavailable'));

    final buyMethods = await provider.getAvailablePaymentTypes('USD', CryptoCurrency.btc, true);
    final sellMethods = await provider.getAvailablePaymentTypes('USD', CryptoCurrency.btc, false);

    expect(buyMethods.map((method) => method.paymentMethodType), [PaymentType.all]);
    expect(sellMethods, isEmpty);
  });

  test('MoonPay respects a successful response that offers no payment methods', () async {
    final provider = _MoonPayProvider(() async => []);

    expect(await provider.getAvailablePaymentTypes('USD', CryptoCurrency.btc, true), isEmpty);
  });
}
