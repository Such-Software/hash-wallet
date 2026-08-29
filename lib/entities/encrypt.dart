import 'dart:convert';

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

// 32-hex `key` candidates (PIN blobs), recovered from the shipped Android
// binaries' string tables. Values present in BOTH binaries are library
// constants and excluded; wrong entries fail validation harmlessly.
const _legacyPinKeys = [
  // 1.0.0 (Play build 9/10)
  '0412c5758f2daac3937a67f4254ba23b',
  '78bcd8e2ae16cd49fdff3a4b15f94a24',
  'd3fa832318c19c65a706032eb5bf3c38',
  // 1.0.1 (Play build 11)
  '51f918406bc771b5827e2479ce24dae0',
  '76d489cc1eb5704e6e4bea65bb2618b3',
  'bba3031d10f37f741c9bcd2b26227cba',
];

// shortKey+walletSalt concatenations (wallet-password blobs).
const _legacyWalletPasswordKeys = [
  // 1.0.0 (2 shortKey x 2 walletSalt candidates)
  '18cfc5c2438f9db902ade81f96b5ee0b',
  '18cfc5c2438f9db902ade81fa70fe053',
  '98cc2fc78b56148a67fa442b96b5ee0b',
  '98cc2fc78b56148a67fa442ba70fe053',
  // 1.0.1
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

// A wallet password is generateKey() output: base64(512-byte key) +
// base64(8-byte iv) = 696 base64 chars. Validate against that exact shape so a
// wrong AES key (which could unpad to arbitrary printable bytes) cannot be
// re-saved as a bogus password. base64.decode round-trips to the exact byte
// lengths, which is astronomically unlikely for a false PKCS7 hit.
bool _looksLikeWalletPassword(String s) {
  if (s.length != 696) return false;
  try {
    final key = base64.decode(s.substring(0, s.length - 12));
    final iv = base64.decode(s.substring(s.length - 12));
    return key.length == 512 && iv.length == 8;
  } catch (_) {
    return false;
  }
}

/// Decode a stored wallet password written by a build with rotated secrets.
/// Returns null when no legacy key fits.
String? decodeWalletPasswordLegacy({required String password}) {
  for (final key in _legacyWalletPasswordKeys) {
    final decrypted = _tryDecrypt(source: password, key: key);
    if (decrypted != null && _looksLikeWalletPassword(decrypted)) return decrypted;
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
