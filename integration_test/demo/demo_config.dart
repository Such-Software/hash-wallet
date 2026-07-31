import 'package:cw_core/wallet_type.dart';

/// Capture-time configuration, injected by `tools/demo/capture.sh` via
/// `--dart-define`. Nothing here is baked into a shipped build.
///
/// The demo wallet seed is pulled from the self-hosted Vaultwarden at capture
/// time and passed straight through — it is never written to the repo, never
/// committed, and never placed in `.secrets.g.dart`.
class DemoConfig {
  /// BIP39 / Wownero seed for the demo wallet.
  static const String walletSeed = String.fromEnvironment('DEMO_WALLET_SEED');

  /// Which wallet the demo restores into. Hash Bags is Wownero-first, so that
  /// is the default face of the app in store material.
  static const String _walletTypeName =
      String.fromEnvironment('DEMO_WALLET_TYPE', defaultValue: 'wownero');

  /// A receive address used to populate the Send screen. This is a
  /// *destination shown on camera*, so it should be an address you are happy
  /// to publish — the capture script defaults it to the demo wallet's own
  /// address rather than a stranger's.
  static const String sendToAddress =
      String.fromEnvironment('DEMO_SEND_ADDRESS');

  /// Amount typed into the Send screen. Never broadcast in the core scenario.
  static const String sendAmount =
      String.fromEnvironment('DEMO_SEND_AMOUNT', defaultValue: '0.5');

  /// Amount typed into the Swap screen.
  static const String swapAmount =
      String.fromEnvironment('DEMO_SWAP_AMOUNT', defaultValue: '10');

  /// PIN used for the demo wallet.
  static List<int> get pin {
    const raw = String.fromEnvironment('DEMO_PIN', defaultValue: '0801');
    return raw.split('').map(int.parse).toList();
  }

  static bool get hasSeed => walletSeed.trim().isNotEmpty;

  static WalletType get walletType {
    switch (_walletTypeName.toLowerCase()) {
      case 'monero':
        return WalletType.monero;
      case 'bitcoin':
        return WalletType.bitcoin;
      case 'litecoin':
        return WalletType.litecoin;
      case 'wownero':
      default:
        return WalletType.wownero;
    }
  }

  /// Human label for captions/log lines.
  static String get walletLabel {
    final n = _walletTypeName.toLowerCase();
    return n.isEmpty ? 'Wownero' : '${n[0].toUpperCase()}${n.substring(1)}';
  }
}
