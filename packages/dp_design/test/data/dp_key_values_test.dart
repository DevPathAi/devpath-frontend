import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {double width = 360}) => MaterialApp(
  theme: DpTheme.light(),
  home: Scaffold(body: Center(child: SizedBox(width: width, child: child))),
);

const _entries = <DpKeyValue>[
  (key: '이번 주', value: Text('1 / 3')),
  (key: '전체 경로', value: Text('12주 중 1주차')),
];

void main() {
  testWidgets('키와 값을 모두 그린다', (tester) async {
    await tester.pumpWidget(_host(const DpKeyValues(entries: _entries)));

    expect(find.text('이번 주'), findsOneWidget);
    expect(find.text('1 / 3'), findsOneWidget);
    expect(find.text('전체 경로'), findsOneWidget);
  });

  testWidgets('키는 보조색이다', (tester) async {
    await tester.pumpWidget(_host(const DpKeyValues(entries: _entries)));

    final style = tester.widget<Text>(find.text('이번 주')).style!;
    expect(style.color, DpColors.light.textSecondary);
  });

  testWidgets('값은 우측 정렬 600 이다', (tester) async {
    await tester.pumpWidget(_host(const DpKeyValues(entries: _entries)));

    final valueStyle = DefaultTextStyle.of(tester.element(find.text('1 / 3')));
    expect(valueStyle.style.fontWeight, FontWeight.w600);
    expect(valueStyle.textAlign, TextAlign.right);
  });

  testWidgets('바깥 패딩은 12×16', (tester) async {
    await tester.pumpWidget(_host(const DpKeyValues(entries: _entries)));

    final pad = tester.widget<Padding>(
      find.byKey(const ValueKey('dp-key-values')),
    );
    expect(
      pad.padding,
      const EdgeInsets.symmetric(
        vertical: DpSpacing.md,
        horizontal: DpSpacing.lg,
      ),
    );
  });
}
