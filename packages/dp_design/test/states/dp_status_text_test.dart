import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(
  theme: DpTheme.light(),
  home: Scaffold(body: child),
);

Text _text(WidgetTester tester) => tester.widget<Text>(find.byType(Text));

void main() {
  testWidgets('done 은 success 색', (tester) async {
    await tester.pumpWidget(
      _host(const DpStatusText(text: '✓ 완료', tone: DpStatusTone.done)),
    );
    expect(_text(tester).style!.color, DpColors.light.success);
  });

  testWidgets('idle 은 보조 텍스트색', (tester) async {
    await tester.pumpWidget(
      _host(const DpStatusText(text: '대기', tone: DpStatusTone.idle)),
    );
    expect(_text(tester).style!.color, DpColors.light.textSecondary);
  });

  testWidgets('current 는 강조 진한색', (tester) async {
    await tester.pumpWidget(
      _host(const DpStatusText(text: '● 다음', tone: DpStatusTone.current)),
    );
    expect(_text(tester).style!.color, DpColors.light.primaryTextStrong);
  });

  testWidgets('12px·600 이고 줄바꿈하지 않는다', (tester) async {
    await tester.pumpWidget(
      _host(const DpStatusText(text: '✓ 해결됨', tone: DpStatusTone.done)),
    );
    final t = _text(tester);
    expect(t.style!.fontSize, 12);
    expect(t.style!.fontWeight, FontWeight.w600);
    expect(t.softWrap, isFalse);
  });

  // 리터럴 TextStyle(fontSize:12) 은 DefaultTextStyle 에 merge 되어 줄 높이를
  // 주변에서 물려받는다. 토큰(labelMedium)은 height 16/12 를 스스로 갖고 있어
  // merge 후 그 값이 이긴다 — 이 테스트가 그 전환을 눈에 보이게 고정한다.
  testWidgets('상태 텍스트는 labelMedium(12 · w600 · height 16/12)으로 그려진다', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const DpStatusText(text: '✓ 완료', tone: DpStatusTone.done)),
    );

    final style = _text(tester).style!;
    expect(style.fontSize, 12);
    expect(style.fontWeight, FontWeight.w600);
    expect(style.height, closeTo(16 / 12, 0.001));
    // 선언(height: 16/12 × fontSize 12)뿐 아니라 그려진 줄 상자도 고정한다 —
    // 계획 Task 6 Step 1 이 요구한 렌더 단언. `labelMedium` 의 height 16/12 ×
    // fontSize 12 = 16 논리픽셀 — 실측값도 정확히 16.0 이었다(허용오차 0.5).
    expect(tester.getSize(find.text('✓ 완료')).height, closeTo(16, 0.5));
  });
}
