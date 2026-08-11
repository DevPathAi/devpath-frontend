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
  testWidgets('WeeklyActivityCard: 데이터 있으면 BarChart 렌더', (tester) async {
    await tester.pumpWidget(
      _host(
        const WeeklyActivityCard(
          activity: [
            DailyActivity(date: '2026-07-25', completedCount: 1),
            DailyActivity(date: '2026-07-31', completedCount: 3),
          ],
        ),
      ),
    );
    await tester.pump();

    expect(find.text('주간 학습량'), findsOneWidget);
    expect(find.byType(BarChart), findsOneWidget);
  });

  testWidgets('WeeklyActivityCard: 전부 0이면 빈 상태 안내', (tester) async {
    await tester.pumpWidget(
      _host(
        const WeeklyActivityCard(
          activity: [
            DailyActivity(date: '2026-07-30', completedCount: 0),
            DailyActivity(date: '2026-07-31', completedCount: 0),
          ],
        ),
      ),
    );
    await tester.pump();

    expect(find.text('아직 학습 기록이 없어요'), findsOneWidget);
    expect(find.byType(BarChart), findsNothing);
  });
}
