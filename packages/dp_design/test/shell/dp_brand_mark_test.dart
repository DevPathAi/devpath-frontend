import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // 브랜드 표기 규칙(2026-10-15): 한국어 화면의 워드마크는 「레바」다. 로고의
  // 스크린리더 라벨만 'Leva' 로 남아 옆 워드마크 「레바」와 다른 이름으로 읽혔다.
  testWidgets('로고는 스크린리더에 「레바」로 읽힌다', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: DpTheme.light(),
        home: const Scaffold(body: Center(child: DpBrandMark())),
      ),
    );

    expect(find.bySemanticsLabel('레바'), findsOneWidget);
    expect(find.bySemanticsLabel('Leva'), findsNothing);
    handle.dispose();
  });
}
