import 'package:devpath_web/src/features/dashboard/presentation/widgets/progress_trend_card.dart';
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(
  theme: DpTheme.light(),
  home: Scaffold(body: child),
);

/// byType에 유형 n종이 **실제로 들어 있는** 히스토리를 만든다.
/// 「유형별로 나눴다」를 선언하는 것과 조건이 성립하는 것은 다르다(3-A의 반복 교훈).
List<ProgressPoint> _history(Map<String, int> byType) => [
  for (var i = 0; i < 14; i++)
    ProgressPoint(
      date: '2026-08-${(i + 1).toString().padLeft(2, '0')}',
      percent: i * 5,
      byType: byType,
    ),
];

void main() {
  testWidgets('유형 3종이면 선 3개와 범례 3개를 렌더한다', (tester) async {
    final history = _history(const {'READ': 80, 'PRACTICE': 40, 'QUIZ': 60});
    // 조건 성립 검산: 계열 키가 정말 3개인가
    expect(history.first.byType.keys.length, 3);

    await tester.pumpWidget(_host(ProgressTrendCard(history: history)));
    await tester.pumpAndSettle();

    final chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(chart.data.lineBarsData.length, 3);
    expect(chart.data.lineBarsData[0].color, DpColors.light.chart1);
    expect(chart.data.lineBarsData[1].color, DpColors.light.chart2);
    expect(chart.data.lineBarsData[2].color, DpColors.light.chart3);
    // 채움은 제거했다 — 반투명 면 3장이 겹치면 계열 판별이 나빠진다.
    // ★`every(...) == isFalse`로 쓰지 마라 — 그것은 「셋 중 하나만 꺼도」 통과한다.
    expect(chart.data.lineBarsData.any((b) => b.belowBarData.show), isFalse);

    expect(find.byType(DpChartLegend), findsOneWidget);
    expect(find.text('읽기'), findsOneWidget);
    expect(find.text('실습'), findsOneWidget);
    expect(find.text('퀴즈'), findsOneWidget);
  });

  testWidgets('유형이 1종뿐이면 선도 범례도 1개다', (tester) async {
    final history = _history(const {'READ': 80});
    expect(history.first.byType.keys.length, 1);

    await tester.pumpWidget(_host(ProgressTrendCard(history: history)));
    await tester.pumpAndSettle();

    final chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(chart.data.lineBarsData.length, 1);
    expect(find.text('실습'), findsNothing);
    // 「선이 1개」만 보면 구현 전(항상 1선)에도 통과해 구별력이 없다.
    // 계열이 1종이어도 **범례는 뜬다**는 것까지 잠가야 이 테스트가 일을 한다.
    expect(find.byType(DpChartLegend), findsOneWidget);
    expect(find.text('읽기'), findsOneWidget);
  });

  testWidgets('byType이 비면 전체 누적률 1선으로 떨어진다', (tester) async {
    // 백엔드가 아직 배포되지 않은 상태(옛 응답)에서도 차트가 살아 있어야 한다.
    final history = _history(const {});

    await tester.pumpWidget(_host(ProgressTrendCard(history: history)));
    await tester.pumpAndSettle();

    final chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(chart.data.lineBarsData.length, 1);
    expect(find.byType(DpChartLegend), findsNothing);
    // 폴백 1선도 **데이터 색**을 쓴다 — 구현 전 c.primary(브랜드 액센트)와 구별된다.
    expect(chart.data.lineBarsData[0].color, DpColors.light.chart1);
  });

  testWidgets('ProgressTrendCard: 빈 배열이면 빈 상태 안내', (tester) async {
    await tester.pumpWidget(_host(const ProgressTrendCard(history: [])));
    await tester.pump();

    expect(find.text('아직 학습 기록이 없어요'), findsOneWidget);
    expect(find.byType(LineChart), findsNothing);
  });
}
