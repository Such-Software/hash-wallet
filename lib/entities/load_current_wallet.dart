import 'package:hash_wallet/di.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hash_wallet/store/app_store.dart';
import 'package:hash_wallet/entities/preferences_key.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:hash_wallet/core/wallet_loading_service.dart';

Future<void> loadCurrentWallet({String? password}) async {
  final appStore = getIt.get<AppStore>();
  final name = getIt.get<SharedPreferences>().getString(PreferencesKey.currentWalletName);
  final typeRaw = getIt.get<SharedPreferences>().getInt(PreferencesKey.currentWalletType) ?? 0;

  if (name == null) {
    throw Exception('Incorrect current wallet name: $name');
  }

  final type = deserializeFromInt(typeRaw);
  final walletLoadingService = getIt.get<WalletLoadingService>();
  final wallet = await walletLoadingService.load(type, name, password: password);
  await appStore.changeCurrentWallet(wallet);
}
