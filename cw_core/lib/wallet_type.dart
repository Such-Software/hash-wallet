import 'package:cw_core/crypto_currency.dart';
import 'package:cw_core/hive_type_ids.dart';
import 'package:hive/hive.dart';

part 'wallet_type.g.dart';

const walletTypes = [
  WalletType.monero,
  WalletType.bitcoin,
  WalletType.litecoin,
  WalletType.ethereum,
  WalletType.bitcoinCash,
  WalletType.nano,
  WalletType.banano,
  WalletType.polygon,
  WalletType.dogecoin,
  WalletType.base,
  WalletType.arbitrum,
  WalletType.bsc,
  WalletType.wownero,
];

const electrumWalletTypes = [
  WalletType.bitcoin,
  WalletType.litecoin,
  WalletType.bitcoinCash,
  WalletType.dogecoin
];

const evmWalletTypes = [
  WalletType.ethereum,
  WalletType.polygon,
  WalletType.base,
  WalletType.arbitrum,
  WalletType.bsc
];

// HiveField IDs are pinned — never renumber. Existing user wallets persist
// type via the int ID, so changing assignments here would re-interpret saved
// wallet types on next launch. To remove a type, drop its enum entry; do not
// re-use its old ID.
@HiveType(typeId: WALLET_TYPE_TYPE_ID)
enum WalletType {
  @HiveField(0)
  monero,

  @HiveField(1)
  none,

  @HiveField(2)
  bitcoin,

  @HiveField(3)
  litecoin,

  @HiveField(5)
  ethereum,

  @HiveField(6)
  nano,

  @HiveField(7)
  banano,

  @HiveField(8)
  bitcoinCash,

  @HiveField(9)
  polygon,

  @HiveField(12)
  wownero,

  @HiveField(15)
  dogecoin,

  @HiveField(16)
  base,

  @HiveField(17)
  arbitrum,

  @HiveField(19)
  bsc,
}

int serializeToInt(WalletType type) {
  switch (type) {
    case WalletType.monero:
      return 0;
    case WalletType.bitcoin:
      return 1;
    case WalletType.litecoin:
      return 2;
    case WalletType.ethereum:
      return 4;
    case WalletType.nano:
      return 5;
    case WalletType.banano:
      return 6;
    case WalletType.bitcoinCash:
      return 7;
    case WalletType.polygon:
      return 8;
    case WalletType.wownero:
      return 11;
    case WalletType.dogecoin:
      return 14;
    case WalletType.base:
      return 15;
    case WalletType.arbitrum:
      return 16;
    case WalletType.bsc:
      return 18;
    case WalletType.none:
      return -1;
  }
}

WalletType deserializeFromInt(int raw) {
  switch (raw) {
    case 0:
      return WalletType.monero;
    case 1:
      return WalletType.bitcoin;
    case 2:
      return WalletType.litecoin;
    case 4:
      return WalletType.ethereum;
    case 5:
      return WalletType.nano;
    case 6:
      return WalletType.banano;
    case 7:
      return WalletType.bitcoinCash;
    case 8:
      return WalletType.polygon;
    case 11:
      return WalletType.wownero;
    case 14:
      return WalletType.dogecoin;
    case 15:
      return WalletType.base;
    case 16:
      return WalletType.arbitrum;
    case 18:
      return WalletType.bsc;
    default:
      throw Exception('Unexpected token: $raw for WalletType deserializeFromInt');
  }
}

String walletTypeToString(WalletType type) {
  switch (type) {
    case WalletType.monero:
      return 'Monero';
    case WalletType.bitcoin:
      return 'Bitcoin';
    case WalletType.litecoin:
      return 'Litecoin';
    case WalletType.ethereum:
      return 'Ethereum';
    case WalletType.bitcoinCash:
      return 'Bitcoin Cash';
    case WalletType.nano:
      return 'Nano';
    case WalletType.banano:
      return 'Banano';
    case WalletType.polygon:
      return 'Polygon';
    case WalletType.wownero:
      return 'Wownero';
    case WalletType.dogecoin:
      return 'Dogecoin';
    case WalletType.base:
      return 'Base';
    case WalletType.arbitrum:
      return 'Arbitrum';
    case WalletType.bsc:
      return 'BNB Smart Chain';
    case WalletType.none:
      return '';
  }
}

String walletTypeToDisplayName(WalletType type) {
  switch (type) {
    case WalletType.monero:
      return 'Monero (XMR)';
    case WalletType.bitcoin:
      return 'Bitcoin (BTC)';
    case WalletType.litecoin:
      return 'Litecoin (LTC)';
    case WalletType.ethereum:
      return 'Ethereum (ETH)';
    case WalletType.bitcoinCash:
      return 'Bitcoin Cash (BCH)';
    case WalletType.nano:
      return 'Nano (XNO)';
    case WalletType.banano:
      return 'Banano (BAN)';
    case WalletType.polygon:
      return 'Polygon (POL)';
    case WalletType.wownero:
      return 'Wownero (WOW)';
    case WalletType.dogecoin:
      return 'Dogecoin (DOGE)';
    case WalletType.base:
      return 'Base';
    case WalletType.arbitrum:
      return 'Arbitrum (ARB)';
    case WalletType.bsc:
      return 'BNB Smart Chain (BNB)';
    case WalletType.none:
      return '';
  }
}

WalletType? _cryptoCurrencyToWalletType(CryptoCurrency type) {
  switch (type) {
    case CryptoCurrency.xmr:
      return WalletType.monero;
    case CryptoCurrency.btc:
    case CryptoCurrency.btcln:
      return WalletType.bitcoin;
    case CryptoCurrency.ltc:
      return WalletType.litecoin;
    case CryptoCurrency.eth:
      return WalletType.ethereum;
    case CryptoCurrency.maticpoly:
      return WalletType.polygon;
    case CryptoCurrency.baseEth:
      return WalletType.base;
    case CryptoCurrency.arbEth:
    case CryptoCurrency.arb:
      return WalletType.arbitrum;
    case CryptoCurrency.bnb:
      return WalletType.bsc;
    case CryptoCurrency.bch:
      return WalletType.bitcoinCash;
    case CryptoCurrency.nano:
      return WalletType.nano;
    case CryptoCurrency.banano:
      return WalletType.banano;
    case CryptoCurrency.wow:
      return WalletType.wownero;
    case CryptoCurrency.doge:
      return WalletType.dogecoin;
    default:
      return null;
  }
}

WalletType? cryptoCurrencyOrTokenToWalletType(CryptoCurrency type) {
  if(type.tag == CryptoCurrency.bnb.tag) {
    return _cryptoCurrencyToWalletType(CryptoCurrency.bnb);
  }

  if(type.tag != null && ![CryptoCurrency.btcln.tag, CryptoCurrency.bnb.tag].contains(type.tag)) {
    return _cryptoCurrencyToWalletType(CryptoCurrency.fromString(type.tag!));
  } else {
    return _cryptoCurrencyToWalletType(type);
  }
}
