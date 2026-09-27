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
}
