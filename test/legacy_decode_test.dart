import 'dart:convert';
import 'package:encrypt/encrypt.dart';
import 'package:flutter_test/flutter_test.dart';

// Mirror of the shipped encode + generateKey (lib/entities/encrypt.dart, cw_core/key.dart)
String enc(String s, String key) =>
    Encrypter(AES(Key.fromUtf8(key))).encrypt(s, iv: IV.allZerosOfLength(16)).base64;
String dec(String s, String key) =>
    Encrypter(AES(Key.fromUtf8(key))).decrypt64(s, iv: IV.allZerosOfLength(16));
String generateKey() => Key.fromSecureRandom(512).base64 + IV.fromSecureRandom(8).base64;
String rnd(int nHexChars) => Key.fromSecureRandom(nHexChars ~/ 2)
    .bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

// Logic under test (identical to lib/entities/encrypt.dart 1.0.2)
bool looksLikeWalletPassword(String s) {
  if (s.length != 696) return false;
  try {
    return base64.decode(s.substring(0, s.length - 12)).length == 512 &&
        base64.decode(s.substring(s.length - 12)).length == 8;
  } catch (_) { return false; }
}
String? tryDecrypt(String source, String key) {
  try {
    final d = dec(source, key);
    return (d.isNotEmpty && d.codeUnits.every((c) => c >= 0x20 && c < 0x7f)) ? d : null;
  } catch (_) { return null; }
}
String? decodePinLegacy(String pin, List<String> keys) {
  for (final key in keys) {
    final d = tryDecrypt(pin, key);
    if (d == null || d.length <= 32) continue;
    final cand = d.substring(32);
    if (cand.isNotEmpty && cand.codeUnits.every((c) => c >= 0x30 && c <= 0x39)) return cand;
  }
  return null;
}
String? decodeWalletLegacy(String pw, List<String> keys) {
  for (final key in keys) {
    final d = tryDecrypt(pw, key);
    if (d != null && looksLikeWalletPassword(d)) return d;
  }
  return null;
}

void main() {
  test('1.0.0 -> 1.0.2 upgrade recovers PIN and wallet password', () {
    final vSalt = rnd(32), vKey = rnd(32), vShort = rnd(24), vWsalt = rnd(8);
    const realPin = '4913';
    final realPw = generateKey();
    final storedPin = enc(vSalt + realPin, vKey);
    final storedPw = enc(realPw, vShort + vWsalt);

    // 1.0.2 legacy lists include the old values among decoys
    final pinKeys = ['deadbeef' * 4, vKey, 'cafef00d' * 4];
    final pwKeys = ['00112233445566778899aabb01020304', vShort + vWsalt];

    expect(decodePinLegacy(storedPin, pinKeys), realPin);
    expect(decodeWalletLegacy(storedPw, pwKeys), realPw);
  });

  test('never false-accepts when the real key is absent', () {
    final vSalt = rnd(32), vKey = rnd(32), vShort = rnd(24), vWsalt = rnd(8);
    final storedPin = enc(vSalt + '271828', vKey);
    final storedPw = enc(generateKey(), vShort + vWsalt);

    var pinFalse = 0, pwFalse = 0;
    for (var i = 0; i < 8000; i++) {
      if (decodePinLegacy(storedPin, [rnd(32)]) != null) pinFalse++;
      if (decodeWalletLegacy(storedPw, [rnd(24) + rnd(8)]) != null) pwFalse++;
    }
    expect(pinFalse, 0, reason: 'PIN false-accepts');
    expect(pwFalse, 0, reason: 'wallet-password false-accepts');
  });
}
