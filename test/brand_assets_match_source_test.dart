import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

// compile_graphics.sh compiles res/pictures/*.svg into assets/new-ui/*.svg.vec,
// and CI runs it on every platform. That makes res/pictures the source and
// assets/new-ui the output, which is easy to get backwards: the files sit side
// by side, have identical names, and the ones under assets/ are the ones the
// Dart code names.
//
// Getting it backwards shipped Cake Wallet's artwork twice. The August de-cake
// pass replaced the copies under assets/new-ui and left res/pictures untouched,
// so every CI build recompiled Cake's icon over the top: their app icon on the
// About screen, and their wordmark on the receive QR page, which is the screen
// a user screenshots to get paid. A local build looked right, because locally
// nobody re-runs the compiler.
//
// So: any SVG present in both places must be byte-identical. If they drift, the
// one under assets/ is a hand-edit that the next CI build will silently revert.
void main() {
  test('brand SVGs under assets/new-ui match their res/pictures source', () {
    final assetsDir = Directory('assets/new-ui');
    final sourceDir = Directory('res/pictures');
    expect(assetsDir.existsSync(), isTrue, reason: 'no assets/new-ui — wrong CWD?');
    expect(sourceDir.existsSync(), isTrue, reason: 'no res/pictures — wrong CWD?');

    final drifted = <String>[];
    var compared = 0;
    for (final f in assetsDir.listSync().whereType<File>()) {
      if (!f.path.endsWith('.svg')) continue;
      final name = f.uri.pathSegments.last;
      final source = File('${sourceDir.path}/$name');
      if (!source.existsSync()) continue; // not compiled from res/pictures
      compared++;
      final a = f.readAsBytesSync();
      final b = source.readAsBytesSync();
      if (a.length != b.length || !_same(a, b)) {
        drifted.add(
          '$name: assets/new-ui is ${a.length}b, res/pictures is ${b.length}b. '
          'Edit res/pictures and re-run ./compile_graphics.sh; the assets copy '
          'is output and CI overwrites it.',
        );
      }
    }

    // A silent zero would make this test vacuous, which is how the last two
    // branding regressions reached users.
    expect(compared, greaterThan(0), reason: 'compared no SVG pairs at all');
    expect(drifted, isEmpty, reason: 'generated brand assets drifted from source:\n${drifted.join('\n')}');
  });
}

bool _same(List<int> a, List<int> b) {
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
