import 'package:devpath_web/src/features/dashboard/presentation/widgets/progress_donut.dart';
import 'package:devpath_web/src/features/dashboard/presentation/widgets/weekly_activity_card.dart';
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(
  theme: DpTheme.light(),
  home: Scaffold(body: child),
);

void main() {
  // 색 단언은 **토큰 참조**로 쓴다(리터럴 hex는 팔레트 계약 테스트의 몫).
  testWidgets('주간 활동 막대는 chart1을 쓴다', (tester) async {
    await tester.pumpWidget(
      _host(
        const WeeklyActivityCard(
          activity: [
            DailyActivity(date: '2026-08-01', completedCount: 2),
            DailyActivity(date: '2026-08-02', completedCount: 3),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final chart = tester.widget<BarChart>(find.byType(BarChart));
    final rod = chart.data.barGroups.first.barRods.first;
    expect(rod.color, DpColors.light.chart1);
  });

  testWidgets('도넛은 완료 chart1 · 미완료 surfaceMuted를 쓴다', (tester) async {
    await tester.pumpWidget(_host(const ProgressDonut(percent: 62)));
    await tester.pumpAndSettle();

    final chart = tester.widget<PieChart>(find.byType(PieChart));
    final sections = chart.data.sections;
    expect(sections.length, 2);
    expect(sections[0].color, DpColors.light.chart1);
    // 경계선 토큰(border)을 데이터 면에 쓰던 오용을 면 토큰으로 바로잡는다.
    expect(sections[1].color, DpColors.light.surfaceMuted);
    expect(sections[1].color, isNot(DpColors.light.border));
  });
}
