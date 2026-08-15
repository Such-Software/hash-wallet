import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/services.dart';

const utils = const MethodChannel('com.cake_wallet/native_utils');

Future<Uint8List> secRandom(int count) async {
  try {
    if (Platform.isWindows || Platform.isLinux) {
      // Used method to get securely generated random bytes from cake backups
      const byteSize = 256;
      final rng = Random.secure();
      return Uint8List.fromList(List<int>.generate(count, (_) => rng.nextInt(byteSize)));
    }
    final bytes = await utils.invokeMethod<Uint8List>('sec_random', {'count': count});
    if (bytes == null || bytes.length != count) {
      throw StateError('sec_random returned ${bytes?.length ?? 0} bytes, expected $count');
    }
    return bytes;
  } on PlatformException catch (e) {
    // Never fail open: an entropy source that cannot deliver must throw,
    // not hand back an empty buffer for key material.
    throw StateError('sec_random platform call failed: ${e.message}');
  }
}
