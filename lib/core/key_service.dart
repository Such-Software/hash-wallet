import 'package:hash_wallet/core/secure_storage.dart';
import 'package:hash_wallet/entities/secret_store_key.dart';
import 'package:hash_wallet/entities/encrypt.dart';

class KeyService {
  KeyService(this._secureStorage);

  final SecureStorage _secureStorage;

  Future<String> getWalletPassword({required String walletName}) async {
    final key =
        generateStoreKeyFor(key: SecretStoreKey.moneroWalletPassword, walletName: walletName);

    // Primary read (current iOS Keychain accessibility).
    var encodedPassword = await _secureStorage.read(key: key);

    // Fallback 1: the legacy read path queries the OTHER iOS Keychain
    // accessibility. A wallet whose password item was written by an older
    // build with different Keychain params reads back null on the primary
    // path — this recovers it. That is the "corrupted seeds after a TestFlight
    // update" failure (Wownero/BTC/etc.: wallet files intact, Keychain entry
    // unreadable under the new params).
    encodedPassword ??= await _secureStorage.readNoIOptions(key: key);

    // Fallback 2: the backup password the Monero password migration saves
    // under a side key BEFORE it re-encrypts, in case the main save did not
    // persist (see WalletLoadingService.updateMoneroWalletPassword).
    if (encodedPassword == null) {
      final bakKey = generateStoreKeyFor(
          key: SecretStoreKey.moneroWalletPassword,
          walletName: '#__${walletName}_bak__#');
      encodedPassword = await _secureStorage.read(key: bakKey) ??
          await _secureStorage.readNoIOptions(key: bakKey);
    }

    // Fail with a clear, CATCHABLE error instead of a null-check crash, so the
    // loader can surface the seed/restore recovery path rather than the app
    // hard-crashing ("crashed and wouldn't let me in").
    if (encodedPassword == null) {
      throw Exception(
          'Wallet password not found in secure storage for "$walletName". '
          'The keychain entry may have been lost across an app update; '
          'restore this wallet from its seed.');
    }

    try {
      return decodeWalletPassword(password: encodedPassword);
    } catch (e) {
      // Legacy-build fallback: blobs written by a build whose generated
      // crypto secrets differed (pre-1.0.2 CI rotated them every build).
      // On success, re-encode under the current key so this install heals.
      final legacy = decodeWalletPasswordLegacy(password: encodedPassword);
      if (legacy != null) {
        await saveWalletPassword(walletName: walletName, password: legacy);
        return legacy;
      }
      rethrow;
    }
  }

  Future<void> saveWalletPassword({required String walletName, required String password}) async {
    final key =
        generateStoreKeyFor(key: SecretStoreKey.moneroWalletPassword, walletName: walletName);
    final encodedPassword = encodeWalletPassword(password: password);

    await _secureStorage.write(key: key, value: encodedPassword);
  }

  Future<void> deleteWalletPassword({required String walletName}) async {
    final key =
        generateStoreKeyFor(key: SecretStoreKey.moneroWalletPassword, walletName: walletName);

    await _secureStorage.delete(key: key);
  }
}
