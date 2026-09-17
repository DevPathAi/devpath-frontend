import 'dart:io';

import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(DpCodeFont.resetForTest);

  test('ensureLoaded registers D2Coding once and caches the future', () async {
    final first = DpCodeFont.ensureLoaded();
    final second = DpCodeFont.ensureLoaded();
    expect(identical(first, second), isTrue);
    expect(DpCodeFont.isLoaded, isFalse);
    await first;
    expect(DpCodeFont.isLoaded, isTrue);
    expect(DpCodeFont.loaded.value, isTrue);
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

  testWidgets('DpMarkdown rebuilds its subtree once the code font is loaded', (
    tester,
  ) async {
    // 첫 레이아웃이 fallback 폰트로 잡은 코드 블록의 스크롤 범위가 시맨틱스에 남아
    // axe scrollable-region-focusable 로 잡혔다(390px, /content, 실측). 폰트가
    // 로드되면 서브트리를 새 키로 다시 만들어 시맨틱스를 새로 생성한다.
    await tester.pumpWidget(
      MaterialApp(
        theme: DpTheme.light(),
        home: const Scaffold(body: DpMarkdown(data: '```dart\n42\n```')),
      ),
    );
    expect(
      find.byKey(const ValueKey('dp-markdown-code-font-false')),
      findsOneWidget,
    );
    await tester.runAsync(DpCodeFont.ensureLoaded);
    await tester.pump();
    expect(
      find.byKey(const ValueKey('dp-markdown-code-font-true')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('dp-markdown-code-font-false')),
      findsNothing,
    );
  });
}
