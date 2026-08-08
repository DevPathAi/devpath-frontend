import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {double width = 400}) => MaterialApp(
  theme: DpTheme.light(),
  home: Scaffold(
    body: SizedBox(width: width, child: child),
  ),
);

void main() {
  testWidgets('항목마다 색 견본과 라벨을 렌더한다', (tester) async {
    await tester.pumpWidget(
      _host(
        DpChartLegend(
          items: [
            (color: DpColors.light.chart1, label: '읽기'),
            (color: DpColors.light.chart2, label: '실습'),
          ],
        ),
      ),
    );

    expect(find.text('읽기'), findsOneWidget);
    expect(find.text('실습'), findsOneWidget);
    // 견본은 색을 그대로 쓴다 — 앱이 넘긴 색이 컴포넌트에서 바뀌면 안 된다.
    final swatches = tester.widgetList<Container>(
      find.byKey(const ValueKey('dp-chart-legend-swatch')),
    );
    expect(swatches.length, 2);
    expect(
      (swatches.first.decoration! as BoxDecoration).color,
      DpColors.light.chart1,
    );
  });

  testWidgets('항목이 1개면 1개만 렌더한다', (tester) async {
    // 유형이 한 종류뿐인 경로에서 범례가 어색해지지 않는지 잠근다.
    await tester.pumpWidget(
      _host(
        DpChartLegend(items: [(color: DpColors.light.chart1, label: '읽기')]),
      ),
    );
    expect(find.text('읽기'), findsOneWidget);
    expect(find.text('실습'), findsNothing);
  });

  testWidgets('좁은 폭에서 오버플로하지 않는다', (tester) async {
    await tester.pumpWidget(
      _host(
        DpChartLegend(
          items: [
            (color: DpColors.light.chart1, label: '읽기'),
            (color: DpColors.light.chart2, label: '실습'),
            (color: DpColors.light.chart3, label: '퀴즈'),
          ],
        ),
        width: 120,
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
