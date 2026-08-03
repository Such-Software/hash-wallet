import 'package:cw_core/crypto_currency.dart';
import 'package:cw_core/wallet_type.dart';

class CommonTestConstants {
  static final pin = [0, 8, 0, 1];
  static final String sendTestAmount = '0.00008';
  static final String sendTestFiatAmount = '1.00';
  static final String exchangeTestAmount = '0.01';
  // Hash Bags is Wownero-first and no longer ships Solana, so the defaults
  // moved off SOL. WalletType.solana does not exist in this fork.
  static final WalletType testWalletType = WalletType.wownero;
  static final String testWalletName = 'Integrated Testing Wallet';
  static final CryptoCurrency sendTestReceiveCurrency = CryptoCurrency.wow;
  static final CryptoCurrency exchangeTestReceiveCurrency = CryptoCurrency.btc;
  static final CryptoCurrency exchangeTestDepositCurrency = CryptoCurrency.wow;
  static final String testWalletAddress =
      'Wo3MWeKwtA918DU4c69hVSNgejdWFCRCuWjShRY66mJkU2Hv58eygJWDJS1MNa2Ge5M1WjUkGHJLAjaZYLBZnDh42Q2u1Es9J';
}
