import 'package:hash_wallet/buy/buy_provider.dart';
import 'package:hash_wallet/buy/moonpay/moonpay_provider.dart';
import 'package:hash_wallet/di.dart';
import 'package:hash_wallet/.secrets.g.dart' as secrets;

enum ProviderType { robinhood, dfx, onramper, moonpay, meld, kriptonim }

extension ProviderTypeName on ProviderType {
  String get title {
    switch (this) {
      case ProviderType.robinhood:
        return 'Robinhood Connect';
      case ProviderType.dfx:
        return 'DFX.swiss';
      case ProviderType.onramper:
        return 'Onramper';
      case ProviderType.moonpay:
        return 'MoonPay';
      case ProviderType.meld:
        return 'Meld';
      case ProviderType.kriptonim:
        return 'Kriptonim';
    }
  }

  String get id {
    switch (this) {
      case ProviderType.robinhood:
        return 'robinhood_connect_provider';
      case ProviderType.dfx:
        return 'dfx_connect_provider';
      case ProviderType.onramper:
        return 'onramper_provider';
      case ProviderType.moonpay:
        return 'moonpay_provider';
      case ProviderType.meld:
        return 'meld_provider';
      case ProviderType.kriptonim:
        return 'kriptonim_provider';
    }
  }
}

class ProvidersHelper {
  // Hash Bags: buy/sell providers stay gutted EXCEPT MoonPay, which is
  // KEY-GATED — it becomes available only when a real moonPayApiKey is baked
  // into the build (injected in CI from the MOONPAY_API_KEY secret; the
  // exchange-helper signer must also be live). If the key is empty the Buy
  // button stays hidden, so v1.0.0 ships cleanly with or without MoonPay.
  // The other providers (Robinhood/DFX/Onramper/Kryptonim/Meld) still need
  // their own partner agreements before re-adding here.
  // Sell/off-ramp: enable by mirroring the buy line below once tested.
  static List<ProviderType> getAvailableBuyProviderTypes() =>
      secrets.moonPayApiKey.isNotEmpty ? [ProviderType.moonpay] : [];
  static List<ProviderType> getAvailableSellProviderTypes() => [];

  static BuyProvider getProviderByType(ProviderType type) {
    switch (type) {
      case ProviderType.moonpay:
        return getIt.get<MoonPayProvider>();
      // The remaining provider implementations (Robinhood/DFX/Onramper/Meld/
      // Kryptonim) were removed; their enum values stay for future re-enable.
      default:
        throw UnsupportedError('Buy provider ${type.title} is not available in this build');
    }
  }
}
