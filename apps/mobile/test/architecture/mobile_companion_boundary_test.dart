import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mobile native source는 companion 경계를 넘지 않는다', () {
    final lib = Directory('lib/src');
    final dartFiles = lib
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .toList();
    final source = dartFiles.map((file) => file.readAsStringSync()).join('\n');

    expect(Directory('lib/src/features/sandbox').existsSync(), isFalse);
    expect(Directory('lib/src/features/review').existsSync(), isFalse);
    expect(Directory('lib/src/features/mentor').existsSync(), isFalse);
    expect(source, isNot(contains("'/onboarding'")));
    expect(source, isNot(contains('"/onboarding"')));
  });
}
