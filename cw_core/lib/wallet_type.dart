import 'package:cw_core/crypto_currency.dart';
import 'package:cw_core/hive_type_ids.dart';
import 'package:cw_core/utils/print_verbose.dart';
import 'package:hive/hive.dart';

part 'wallet_type.part.dart';

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

// Two encodings are persisted; never change either.
// - The HiveField IDs are the bytes WalletTypeAdapter (wallet_type.part.dart) reads when legacy
//   Hive data is migrated. To remove a type, drop it; never reuse its ID.
// - WalletType.index is what the SQLite wallet table stores (wallet_info.dart), so the enum
//   ORDER is persisted as well: only ever append. Our order differs from upstream's, so a merge
//   must never take upstream's enum.
// hive_generator no longer runs (upstream froze the adapters into *.part.dart); the annotations
// below are kept as the record of the IDs.
// @HiveType(typeId: WALLET_TYPE_TYPE_ID)
enum WalletType {
  // @HiveField(0)
  monero,

  // @HiveField(1)
  none,

  // @HiveField(2)
  bitcoin,

  // @HiveField(3)
  litecoin,

  // @HiveField(5)
  ethereum,

  // @HiveField(6)
  nano,

  // @HiveField(7)
  banano,

  // @HiveField(8)
  bitcoinCash,

  // @HiveField(9)
  polygon,

  // @HiveField(12)
  wownero,

  // @HiveField(15)
  dogecoin,

  // @HiveField(16)
  base,

  // @HiveField(17)
  arbitrum,

  // @HiveField(19)
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

String walletTypeToDisplayName(WalletType type) => switch (type) {
      WalletType.monero => 'Monero',
      WalletType.bitcoin => 'Bitcoin',
      WalletType.litecoin => 'Litecoin',
      WalletType.ethereum => 'Ethereum',
      WalletType.bitcoinCash => 'Bitcoin Cash',
      WalletType.nano => 'Nano',
      WalletType.banano => 'Banano',
      WalletType.polygon => 'Polygon',
      WalletType.wownero => 'Wownero',
      WalletType.dogecoin => 'Dogecoin',
      WalletType.base => 'Base',
      WalletType.arbitrum => 'Arbitrum',
      WalletType.bsc => 'BNB Smart Chain',
      WalletType.none => ''
    };

String walletTypeToDisplayTicker(WalletType type) => switch (type) {
      WalletType.monero => 'XMR',
      WalletType.bitcoin => 'BTC',
      WalletType.litecoin => 'LTC',
      WalletType.ethereum => 'ETH',
      WalletType.bitcoinCash => 'BCH',
      WalletType.nano => 'XNO',
      WalletType.banano => 'BAN',
      WalletType.polygon => 'POL',
      WalletType.wownero => 'WOW',
      WalletType.dogecoin => 'DOGE',
      WalletType.base => '',
      WalletType.arbitrum => 'ARB',
      WalletType.bsc => 'BNB',
      WalletType.none => ''
    };

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
  if (type.tag == CryptoCurrency.bnb.tag) {
    return _cryptoCurrencyToWalletType(CryptoCurrency.bnb);
  }

  if (type.tag != null && ![CryptoCurrency.btcln.tag, CryptoCurrency.bnb.tag].contains(type.tag)) {
    return _cryptoCurrencyToWalletType(CryptoCurrency.fromString(type.tag!));
  } else {
    return _cryptoCurrencyToWalletType(type);
  }
}
