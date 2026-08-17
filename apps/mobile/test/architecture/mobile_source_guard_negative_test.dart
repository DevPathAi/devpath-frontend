import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Future<ProcessResult> _scan(String source) async {
  final fixture = await Directory.systemTemp.createTemp(
    'leva-mobile-source-guard-',
  );
  addTearDown(() => fixture.delete(recursive: true));
  final lib = Directory('${fixture.path}/lib')..createSync();
  File('${lib.path}/main.dart').writeAsStringSync(source);
  return Process.run(_dartExecutable(), [
    'run',
    '../../tools/mobile_source_guard.dart',
    '--source-only=${lib.path}',
  ]);
}

String _dartExecutable() {
  var directory = File(Platform.resolvedExecutable).parent;
  while (directory.parent.path != directory.path) {
    final candidate = File(
      '${directory.path}/bin/${Platform.isWindows ? 'dart.bat' : 'dart'}',
    );
    if (candidate.existsSync()) return candidate.path;
    directory = directory.parent;
  }
  return Platform.resolvedExecutable;
}

void main() {
  test('source-only fixture accepts platform-neutral mobile Dart', () async {
    final result = await _scan('void main() {}');
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
  });

  for (final forbidden in <String, String>{
    'dart:html': "import 'dart:html'; void main() {}",
    'dart:js': "import 'dart:js'; void main() {}",
    'dart:js_interop': "import 'dart:js_interop'; void main() {}",
    'localStorage': 'void main() { localStorage.clear(); }',
    'sessionStorage': 'void main() { sessionStorage.clear(); }',
  }.entries) {
    test('source-only fixture rejects ${forbidden.key}', () async {
      final result = await _scan(forbidden.value);
      expect(result.exitCode, isNot(0), reason: forbidden.key);
      expect('${result.stdout}${result.stderr}', contains(forbidden.key));
    });
  }
}
