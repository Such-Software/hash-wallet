import 'package:encrypt/encrypt.dart';
// import 'package:password/password.dart';
import 'package:hash_wallet/.secrets.g.dart' as secrets;

String encrypt({required String source, required String key}) {
  final _key = Key.fromUtf8(key);
  final iv = IV.allZerosOfLength(16);
  final encrypter = Encrypter(AES(_key));
  final encrypted = encrypter.encrypt(source, iv: iv);

  return encrypted.base64;
}

String decrypt({required String source, required String key}) {
  final _key = Key.fromUtf8(key);
  final iv = IV.allZerosOfLength(16);
  final encrypter = Encrypter(AES(_key));
  final decrypted = encrypter.decrypt64(source, iv: iv);

  return decrypted;
}

String hash({required String source}) {
  // FIX-ME: Uninplemented
  throw Exception('Unimplemented');
  // final algorithm = PBKDF2();
  // final hash = Password.hash(source, algorithm);

  // return hash;
}

String encodedPinCode({required String pin}) {
  final source = '${secrets.salt}$pin';

  return encrypt(source: source, key: secrets.key);
}

String decodedPinCode({required String pin}) {
  final decrypted = decrypt(source: pin, key: secrets.key);

  return decrypted.substring(secrets.key.length, decrypted.length);
}

String encodeWalletPassword({required String password}) {
  final source = password;
  final _key = secrets.shortKey + secrets.walletSalt;

  return encrypt(source: source, key: _key);
}

String decodeWalletPassword({required String password}) {
  final source = password;
  final _key = secrets.shortKey + secrets.walletSalt;

  return decrypt(source: source, key: _key);
}

// ---------------------------------------------------------------------------
// Legacy-build compatibility (1.0.2 hotfix).
//
// CI builds before 1.0.2 regenerated the crypto secrets on EVERY build
// (tool/generate_new_secrets.dart runs unpinned in the workflow), so each
// shipped binary encrypted the stored PIN / wallet passwords under different
// keys. Updating the app then broke decryption of everything the previous
// build had stored: "Invalid or corrupted pad block" at PIN entry and the
// "Corrupted seeds" dialog, with wallet files themselves perfectly intact.
//
// The values below are recovered from shipped release binaries (string table
// of libapp.so). On a primary decrypt failure the callers retry with these
// and re-encrypt under the current pinned key on success, so every install
// self-heals on its first successful unlock. A wrong key can slip past
// PKCS7 unpadding (~0.4%), so decoded output is validated before acceptance.

// 32-hex `key` candidates (PIN blobs). Includes every plausible constant from
// the 1.0.1 Android string table; wrong entries fail validation harmlessly.
const _legacyPinKeys = [
  '51f918406bc771b5827e2479ce24dae0',
  '5a0e830aa102994045c19a4fef0d3156',
  '76d489cc1eb5704e6e4bea65bb2618b3',
  'bba3031d10f37f741c9bcd2b26227cba',
  'd6031998d1b3bbfebf59cc9bbff9aee1',
  '5eeefca380d02919dc2c6558bb6d8a5d',
];

// shortKey+walletSalt concatenations (wallet-password blobs), 1.0.1 Android.
const _legacyWalletPasswordKeys = [
  'b77ed95e692db912ff0463821f37e159',
  'be2a818b190ab41010f0e2871f37e159',
];

String? _tryDecrypt({required String source, required String key}) {
  try {
    final decrypted = decrypt(source: source, key: key);
    final printable =
        decrypted.isNotEmpty && decrypted.codeUnits.every((c) => c >= 0x20 && c < 0x7f);
    return printable ? decrypted : null;
  } catch (_) {
    return null;
  }
}

/// Decode a stored wallet password written by a build with rotated secrets.
/// Returns null when no legacy key fits.
String? decodeWalletPasswordLegacy({required String password}) {
  for (final key in _legacyWalletPasswordKeys) {
    final decrypted = _tryDecrypt(source: password, key: key);
    if (decrypted != null) return decrypted;
  }
  return null;
}

/// Decode a stored PIN blob written by a build with rotated secrets.
/// The plaintext layout is 32-char salt + digits; returns null if nothing fits.
String? decodedPinCodeLegacy({required String pin}) {
  for (final key in _legacyPinKeys) {
    final decrypted = _tryDecrypt(source: pin, key: key);
    if (decrypted == null || decrypted.length <= 32) continue;
    final candidate = decrypted.substring(32);
    final digitsOnly = candidate.codeUnits.every((c) => c >= 0x30 && c <= 0x39);
    if (digitsOnly) return candidate;
  }
  return null;
}
