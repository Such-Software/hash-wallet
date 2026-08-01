import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Shared plumbing for the marketing / store-capture scenarios.
///
/// These scenarios are NOT correctness tests. They exist to drive the real app
/// through real flows at a pace a human can watch, while the host records the
/// screen. Three things separate them from the suites in `test_suites/`:
///
///  1. **Pacing.** A passing test rips through screens in milliseconds. That
///     footage is unwatchable. [beat] holds on a screen long enough to read it.
///
///  2. **Marks.** Each beat is timestamped relative to session start and
///     reported through `binding.reportData`, which the driver writes to
///     `integration_test/integration_response_data.json`. `capture.sh` reads
///     that file to build the reel manifest, so captions land on the exact
///     frame the action happens instead of being hand-timed.
///
///  3. **Seed safety.** The demo wallet is a REAL wallet. [guardNoSeedOnScreen]
///     fails the run if a mnemonic is visible while recording, so a seed can
///     never end up in a published video. Scenarios that must pass through a
///     seed screen wrap it in [blindfold].
class DemoSession {
  DemoSession(this.tester, this.binding, this.scenario);

  final WidgetTester tester;
  final IntegrationTestWidgetsFlutterBinding binding;
  final String scenario;

  final Stopwatch _clock = Stopwatch();
  final List<Map<String, dynamic>> _marks = <Map<String, dynamic>>[];

  /// Device-clock epoch (ms) at the moment the scenario started.
  ///
  /// The host starts `adb screenrecord` before the app is even installed, so
  /// mark timestamps (relative to scenario start) mean nothing to the video
  /// on their own. capture.sh reads the device clock at record start, and the
  /// difference between that and this value is the offset from the first frame
  /// of video to mark 0. Both numbers come from the DEVICE clock, so host/guest
  /// clock skew cannot corrupt the alignment.
  int startedAtEpochMs = 0;

  /// Words that, seen together in bulk, mean a mnemonic is on screen.
  static const int _mnemonicWordThreshold = 12;

  /// Extra secrets the host injects (the demo wallet seed) that must never be
  /// rendered while the camera rolls. Populated from --dart-define.
  static const String _demoSeed = String.fromEnvironment('DEMO_WALLET_SEED');

  double get _elapsed => _clock.elapsedMilliseconds / 1000.0;

  void begin() {
    startedAtEpochMs = DateTime.now().millisecondsSinceEpoch;
    _clock.start();
    _marks.add(<String, dynamic>{
      'at': 0.0,
      'label': 'start',
      'caption': null,
    });
  }

  /// Record a beat. [caption], when given, becomes a burned caption in the
  /// social reel at exactly this timestamp.
  void mark(String label, {String? caption}) {
    _marks.add(<String, dynamic>{
      'at': double.parse(_elapsed.toStringAsFixed(3)),
      'label': label,
      'caption': caption,
    });
    tester.printToConsole('[demo:$scenario] ${_elapsed.toStringAsFixed(2)}s  $label');
  }

  /// Hold on the current screen for [seconds] of WALL CLOCK time, pumping
  /// frames throughout.
  ///
  /// Deliberately not `pumpAndSettle`: the dashboard runs a perpetual sync
  /// indicator animation, so `pumpAndSettle` would spin until it times out.
  /// Pumping on a wall-clock deadline is both safe and what makes the footage
  /// watchable.
  Future<void> beat([double seconds = 1.6]) async {
    final deadline = DateTime.now().add(
      Duration(milliseconds: (seconds * 1000).round()),
    );
    while (DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 33)); // ~30fps
    }
  }

  /// Beat, then record a mark — the common "let the viewer read this" move.
  Future<void> hold(String label, {String? caption, double seconds = 1.8}) async {
    mark(label, caption: caption);
    await beat(seconds);
  }

  /// Tap a finder with camera-friendly lead-in and follow-through, so the
  /// viewer sees WHAT is about to be tapped before the screen changes.
  Future<void> tap(
    Finder finder, {
    required String label,
    String? caption,
    double before = 0.9,
    double after = 1.4,
  }) async {
    await beat(before);
    mark(label, caption: caption);
    await tester.tap(finder, warnIfMissed: false);
    await beat(after);
  }

  /// Type text at human speed instead of instantly, which reads as a paste and
  /// looks fake on camera. `perChar` is the inter-keystroke delay.
  Future<void> typeSlowly(
    Finder field,
    String text, {
    double perChar = 0.06,
  }) async {
    await tester.tap(field, warnIfMissed: false);
    await beat(0.4);
    final buffer = StringBuffer();
    for (final rune in text.runes) {
      buffer.writeCharCode(rune);
      await tester.enterText(field, buffer.toString());
      await tester.pump(Duration(milliseconds: (perChar * 1000).round()));
    }
    await beat(0.5);
  }

  /// Every rendered string currently on screen.
  Iterable<String> _visibleText() sync* {
    for (final element in find.byType(Text).evaluate()) {
      final widget = element.widget as Text;
      final data = widget.data;
      if (data != null && data.isNotEmpty) yield data;
    }
    for (final element in find.byType(EditableText).evaluate()) {
      final widget = element.widget as EditableText;
      final data = widget.controller.text;
      if (data.isNotEmpty) yield data;
    }
  }

  /// Fail loudly if a mnemonic is on screen while recording.
  ///
  /// Two independent checks, because either alone has a blind spot: the known
  /// demo seed may be split across widgets, and an unknown seed (a freshly
  /// generated one) will not match any known string.
  void guardNoSeedOnScreen({String? because}) {
    final visible = _visibleText().toList();

    if (_demoSeed.isNotEmpty) {
      final needle = _demoSeed.trim().toLowerCase();
      final haystack = visible.join(' ').toLowerCase();
      if (haystack.contains(needle)) {
        fail('SEED ON CAMERA (demo wallet seed rendered) '
            '${because ?? ''} — scenario "$scenario". Recording aborted.');
      }
      // Also catch the seed rendered one-word-per-widget.
      final words = needle.split(RegExp(r'\s+')).toSet();
      final onScreenWords = haystack.split(RegExp(r'[^a-z]+')).toSet();
      final overlap = words.intersection(onScreenWords).length;
      if (words.length >= _mnemonicWordThreshold &&
          overlap >= _mnemonicWordThreshold) {
        fail('SEED ON CAMERA (demo seed words rendered individually, '
            '$overlap matches) ${because ?? ''} — scenario "$scenario".');
      }
    }

    // Generic shape check: any single widget holding many lowercase words is
    // almost certainly a mnemonic in this app.
    for (final text in visible) {
      final words = text
          .trim()
          .split(RegExp(r'\s+'))
          .where((w) => RegExp(r'^[a-zA-Z]{3,}$').hasMatch(w))
          .toList();
      if (words.length >= _mnemonicWordThreshold) {
        fail('SEED ON CAMERA (widget holds ${words.length} word-like tokens) '
            '${because ?? ''} — scenario "$scenario". Recording aborted.');
      }
    }
  }

  /// Run [body] with the recording explicitly marked as unsafe-to-publish.
  ///
  /// Used for the unavoidable seed screens in the create/restore scenarios.
  /// The frames still get recorded — we cannot stop the host recorder from
  /// here — so this brackets them with marks. `capture.sh` reads the resulting
  /// `blindfold` spans and passes them to reel.py as regions to cut, and
  /// refuses to emit a publishable master if any span is unhandled.
  Future<void> blindfold(String reason, Future<void> Function() body) async {
    mark('blindfold_start', caption: null);
    tester.printToConsole(
      '[demo:$scenario] BLINDFOLD START ($reason) — frames from here are '
      'NOT publishable until cut',
    );
    try {
      await body();
    } finally {
      mark('blindfold_end', caption: null);
      tester.printToConsole('[demo:$scenario] BLINDFOLD END');
    }
  }

  /// Publish the marks back to the host through the driver.
  void finish() {
    _clock.stop();
    mark('end');
    final existing = binding.reportData ?? <String, dynamic>{};
    existing['demo'] = <String, dynamic>{
      'scenario': scenario,
      'started_at_epoch_ms': startedAtEpochMs,
      'duration': double.parse(_elapsed.toStringAsFixed(3)),
      'marks': _marks,
      'blindfold_spans': _blindfoldSpans(),
    };
    binding.reportData = existing;
  }

  /// Pair up blindfold_start/blindfold_end marks into [start, end] windows.
  List<Map<String, double>> _blindfoldSpans() {
    final spans = <Map<String, double>>[];
    double? open;
    for (final m in _marks) {
      if (m['label'] == 'blindfold_start') {
        open = m['at'] as double;
      } else if (m['label'] == 'blindfold_end' && open != null) {
        spans.add(<String, double>{'start': open, 'end': m['at'] as double});
        open = null;
      }
    }
    // An unclosed span means the scenario crashed mid-seed. Treat the whole
    // remainder as unsafe rather than assuming it ended.
    if (open != null) {
      spans.add(<String, double>{'start': open, 'end': _elapsed});
    }
    return spans;
  }
}
