import 'package:cw_core/wallet_type.dart';
import 'package:cw_core/utils/print_verbose.dart';
import 'package:flutter/foundation.dart';
import 'package:hash_wallet/core/auth_service.dart';
import 'package:hash_wallet/core/execution_state.dart';
import 'package:hash_wallet/core/new_wallet_arguments.dart';
import 'package:hash_wallet/di.dart';
import 'package:hash_wallet/entities/load_current_wallet.dart';
import 'package:hash_wallet/entities/preferences_key.dart';
import 'package:hash_wallet/entities/seed_type.dart';
import 'package:hash_wallet/store/authentication_store.dart';
import 'package:hash_wallet/view_model/wallet_new_vm.dart';
import 'package:hash_wallet/view_model/wallet_restore_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether this build was launched in capture/demo mode.
///
/// Compile-time const AND gated on [kDebugMode], so in a release build both
/// halves fold to false and every demo path below is tree-shaken out. It is
/// impossible to enable DEMO_MODE in a store binary.
///
/// Enable for a local capture build with:
///   flutter run --dart-define=DEMO_MODE=true
///
/// SCREENSHOT_MODE is honored as an alias so the iOS fastlane snapshot UITest
/// (ios/RunnerUITests/HashBagsScreenshotsUITests.swift, which already passes
/// --dart-define=SCREENSHOT_MODE=true) drives this same path unchanged.
const bool _demoModeDefine = bool.fromEnvironment('DEMO_MODE');
const bool _screenshotModeDefine = bool.fromEnvironment('SCREENSHOT_MODE');
bool get isDemoMode => kDebugMode && (_demoModeDefine || _screenshotModeDefine);

/// PIN the demo build "unlocks" with.
const String _demoPin = String.fromEnvironment('DEMO_PIN', defaultValue: '0801');

/// Name of the throwaway wallet the demo build creates on first launch.
const String _demoWalletName = 'Demo Wallet';

/// Optional fixed seed. When set, the demo build RESTORES this exact wallet
/// instead of creating a fresh one — so a funded throwaway wallet is
/// reproducible and its balance (which lives on-chain against the seed)
/// survives any emulator wipe. THROWAWAY only; never a real wallet. Supplied
/// via --dart-define, kept out of git (tools/demo/demo.env).
const String _demoSeed = String.fromEnvironment('DEMO_WALLET_SEED');

/// Restore height for the seed above. Set it near the wallet's creation block
/// so sync is fast; 0 scans from genesis (slow).
const int _demoHeight = int.fromEnvironment('DEMO_WALLET_HEIGHT', defaultValue: 0);

/// Bring the app up straight into a usable, unlocked wallet so the capture
/// harness never has to drive onboarding or the PIN pad (whose synthetic taps
/// are unreliable under the headless emulator).
///
/// First launch: create a fresh Wownero wallet through the real new-wallet
/// view model — so walletInfo, derivation, paths, persistence and
/// changeCurrentWallet all happen exactly as they do in the UI flow, just
/// without the screens. No seed import, no network sync: instant, deterministic,
/// zero balance. Later launches: reuse the wallet already on disk.
///
/// This is a THROWAWAY wallet. Never fund it. To shoot balances/history, point
/// a demo build at a funded wallet instead (out of scope here).
Future<void> maybeSetupDemoWallet() async {
  if (!isDemoMode) return;

  try {
    final authStore = getIt.get<AuthenticationStore>();
    final authService = getIt.get<AuthService>();
    final prefs = getIt.get<SharedPreferences>();

    await authService.setPassword(_demoPin);

    final existing = prefs.getString(PreferencesKey.currentWalletName);
    if (existing != null) {
      // A demo wallet already exists from a prior run — just load it.
      await loadCurrentWallet();
      authStore.allowed();
      printV('[demo] loaded existing wallet "$existing"');
      return;
    }

    if (_demoSeed.trim().isNotEmpty) {
      // Reproducible funded wallet: restore the fixed seed. WalletRestoreView
      // Model shares WalletCreationVM.create, so it builds walletInfo/paths and
      // finalizes (changeCurrentWallet + allowedCreate) just like the new-wallet
      // flow.
      final vm = getIt.get<WalletRestoreViewModel>(
          param1: WalletType.wownero, param2: null);
      vm.name = _demoWalletName;
      // getCredentials() reads name/passphrase FROM the options map (not the vm
      // field), and casts name as a non-null String — so it must be present.
      await vm.create(options: <String, dynamic>{
        'name': _demoWalletName,
        'seed': _demoSeed.trim(),
        'height': _demoHeight,
        'passphrase': '',
      });
      if (vm.state is! ExecutedSuccessfullyState) {
        throw Exception('wallet restore did not finish (${vm.state.runtimeType})');
      }
      printV('[demo] restored Wownero wallet from DEMO_WALLET_SEED '
          '(height $_demoHeight)');
      return;
    }

    // Fresh Wownero wallet via the real create flow. WalletNewVM.create builds
    // the WalletInfo, derivation, and paths, creates + saves the wallet, calls
    // AppStore.changeCurrentWallet (persisting currentWalletName/type) and
    // AuthenticationStore.allowedCreate() on success.
    final vm = getIt.get<WalletNewVM>(
        param1: NewWalletArguments(type: WalletType.wownero));
    vm.name = _demoWalletName;
    await vm.create(options: <dynamic>['English', MoneroSeedType.polyseed]);

    if (vm.state is! ExecutedSuccessfullyState) {
      throw Exception('wallet create did not finish (${vm.state.runtimeType})');
    }
    printV('[demo] created fresh Wownero wallet "$_demoWalletName"');
  } catch (e, s) {
    // Never let a demo-only path crash the app; fall back to normal onboarding
    // so the failure is visible rather than fatal.
    printV('[demo] setup failed, falling back to onboarding: $e\n$s');
  }
}
