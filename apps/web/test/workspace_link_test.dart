import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('apps/web가 workspace 멤버 dp_design을 cross-import해 렌더한다', (
    tester,
  ) async {
    // P3: DpBrandMark 제거됨 → 현재 공개 API(DpTheme/DpEmpty)로 cross-import 검증.
    // context.dpColors를 쓰는 위젯이므로 DpTheme.light() 주입 필요(P4a-A 교훈).
    await tester.pumpWidget(
      MaterialApp(
        theme: DpTheme.light(),
        home: const Scaffold(body: DpEmpty(title: 'DevPath')),
      ),
    );
    expect(find.text('DevPath'), findsOneWidget); // dp_design 심볼이 실제로 해석됨
  });
}
