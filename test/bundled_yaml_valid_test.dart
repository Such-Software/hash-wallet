import 'dart:io';
import 'package:yaml/yaml.dart';
import 'package:flutter_test/flutter_test.dart';

// Guards against the 1.0.2-era crash: a duplicate mapping key in a bundled
// node list (polygon_node_list.yml had two `useSSL`). PyYAML tolerates it,
// but the app parses with package:yaml, which throws "Duplicate mapping key"
// at runtime. Every bundled *.yml the app can loadYaml() must parse cleanly.
void main() {
  test('all bundled node-list YAML assets parse under package:yaml', () {
    final dir = Directory('assets');
    final ymls = dir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.yml') || f.path.endsWith('.yaml'))
        .toList();
    expect(ymls, isNotEmpty, reason: 'no YAML assets found — wrong CWD?');

    final failures = <String>[];
    for (final f in ymls) {
      try {
        loadYaml(f.readAsStringSync());
      } catch (e) {
        failures.add('${f.path}: $e');
      }
    }
    expect(failures, isEmpty, reason: 'YAML assets rejected by package:yaml:\n${failures.join('\n')}');
  });
}
