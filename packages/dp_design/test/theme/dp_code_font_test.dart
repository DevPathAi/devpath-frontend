import 'dart:io';

import 'package:dp_design/dp_design.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(DpCodeFont.resetForTest);

  test('ensureLoaded registers D2Coding once and caches the future', () async {
    final first = DpCodeFont.ensureLoaded();
    final second = DpCodeFont.ensureLoaded();
    expect(identical(first, second), isTrue);
    await first;
    expect(DpCodeFont.isLoaded, isTrue);
    expect(DpCodeFont.assetPath, 'packages/dp_design/fonts/D2Coding.ttf');
  });

  test('D2Coding is a lazy asset, not a FontManifest font', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(
      pubspec,
      contains('  assets:\n    - fonts/D2Coding.ttf\n'),
      reason: 'D2Coding must stay packaged so the lazy loader can fetch it',
    );
    expect(
      pubspec,
      isNot(contains('- asset: fonts/D2Coding.ttf')),
      reason: 'FontManifest must not preload the 2 MB code font at startup',
    );
    expect(pubspec, contains('- asset: fonts/Pretendard-Regular.otf'));
    expect(pubspec, contains('- asset: fonts/Pretendard-Bold.otf'));
  });
}
