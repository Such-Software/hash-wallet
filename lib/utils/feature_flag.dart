import 'package:cw_core/utils/proxy_wrapper.dart';
import 'package:cw_core/utils/tor/disabled.dart';
import 'package:flutter/foundation.dart';

class FeatureFlag {
  // Hash Bags: Lightning disabled — running Greenlight/LSP infra is out of
  // scope for now. Re-enable once we have an LSP relationship lined up.
  static const bool isLightningEnabled = false;
  // Hash Bags: the charts tab reads Cake's prices.cakewallet.com history API. Off until
  // prices.neroswap.com serves history; PriceApiClient makes no requests while it is false.
  static const bool isChartsEnabled = false;
  static const bool isBackgroundSyncEnabled = true;
  static bool get isInAppTorEnabled => CakeTor.instance is! CakeTorDisabled;
  static const int verificationWordsCount = kDebugMode || kProfileMode ? 0 : 2;
  static const bool hasDevOptions =
      bool.fromEnvironment('hasDevOptions', defaultValue: kDebugMode || kProfileMode);
  static const bool hasBitcoinViewOnly = true;
  static const bool customBackgroundEnabled = false;
  static const bool duressPinEnabled = true;
  static const bool isEVMChainSwitcherEnabled = false;
  static const bool isAutomaticNodeSwitchingEnabled = false;
}
