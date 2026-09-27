import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) =>
    MaterialApp(theme: DpTheme.light(), home: Scaffold(body: child));

void main() {
  testWidgets('자식을 모두 그리고 마지막만 구분선이 없다', (tester) async {
    await tester.pumpWidget(
      _host(const DpListLines(children: [Text('첫째'), Text('둘째'), Text('셋째')])),
    );

    final items = tester
        .widgetList<Container>(find.byKey(const ValueKey('dp-list-line')))
        .toList();
    expect(items.length, 3);
    expect(
      (items[0].decoration! as BoxDecoration).border!.bottom.color,
      DpColors.light.border,
    );
    expect((items[1].decoration! as BoxDecoration).border!.bottom.width, 1);
    expect((items[2].decoration! as BoxDecoration).border, isNull);
    expect(find.text('셋째'), findsOneWidget);
  });

  testWidgets('항목 패딩은 세로 10 가로 16', (tester) async {
    await tester.pumpWidget(_host(const DpListLines(children: [Text('하나')])));

    final item = tester.widget<Container>(
      find.byKey(const ValueKey('dp-list-line')),
    );
    expect(
      item.padding,
      const EdgeInsets.symmetric(vertical: 10, horizontal: DpSpacing.lg),
    );
  });

  testWidgets('자식이 없으면 아무것도 그리지 않는다', (tester) async {
    await tester.pumpWidget(_host(const DpListLines(children: [])));

    expect(find.byKey(const ValueKey('dp-list-line')), findsNothing);
  });
}
