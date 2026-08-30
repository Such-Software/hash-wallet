import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

/// Drives the on-device Wownero node daemon (wownerod) bundled in the APK.
///
/// Android only for now — the native side execs the daemon from the app's
/// nativeLibraryDir. On any other platform every call is a no-op returning a
/// not-running state, so callers can use it unconditionally.
class EmbeddedNode {
  EmbeddedNode._();

  static const _channel = MethodChannel('cash.hashbags/embedded_node');

  static bool get supported => Platform.isAndroid;

  /// The wallet connects to the local node at this address once it's up.
  static Future<String> address() async {
    final port = supported ? (await _channel.invokeMethod<int>('rpcPort') ?? 34568) : 34568;
    return '127.0.0.1:$port';
  }

  /// Start the daemon. Pruned mode (~3.5GB) is the on-phone default; full is
  /// ~11GB. Returns true if the node is (now) running.
  static Future<bool> start({bool pruned = true}) async {
    if (!supported) return false;
    return await _channel.invokeMethod<bool>('start', {'pruned': pruned}) ?? false;
  }

  static Future<void> stop() async {
    if (!supported) return;
    await _channel.invokeMethod<void>('stop');
  }

  static Future<EmbeddedNodeStatus> status() async {
    if (!supported) return const EmbeddedNodeStatus.stopped();
    final m = await _channel.invokeMapMethod<String, dynamic>('progress');
    if (m == null) return const EmbeddedNodeStatus.stopped();
    return EmbeddedNodeStatus(
      running: m['running'] == true,
      height: (m['height'] as num?)?.toInt() ?? 0,
      targetHeight: (m['targetHeight'] as num?)?.toInt() ?? 0,
      synced: m['synced'] == true,
    );
  }

  static Future<String> logs() async {
    if (!supported) return '';
    return await _channel.invokeMethod<String>('logs') ?? '';
  }

  /// Poll status until the RPC is reachable (or [timeout]); lets a caller wait
  /// before pointing the wallet at the local node.
  static Future<bool> waitUntilReady(
      {Duration timeout = const Duration(seconds: 90)}) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final s = await status();
      if (!s.running) return false;
      if (await _rpcReachable()) return true;
      await Future<void>.delayed(const Duration(seconds: 2));
    }
    return false;
  }

  static Future<bool> _rpcReachable() async {
    try {
      final port = supported ? (await _channel.invokeMethod<int>('rpcPort') ?? 34568) : 34568;
      final socket = await Socket.connect('127.0.0.1', port,
          timeout: const Duration(seconds: 2));
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }
}

class EmbeddedNodeStatus {
  final bool running;
  final int height;
  final int targetHeight;
  final bool synced;

  const EmbeddedNodeStatus({
    required this.running,
    required this.height,
    required this.targetHeight,
    required this.synced,
  });

  const EmbeddedNodeStatus.stopped()
      : running = false,
        height = 0,
        targetHeight = 0,
        synced = false;

  double get progress =>
      targetHeight > 0 ? (height / targetHeight).clamp(0.0, 1.0) : 0.0;
}
