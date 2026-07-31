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

void main() {
  testWidgets('ProgressTrendCard: 데이터 있으면 LineChart 렌더', (tester) async {
    await tester.pumpWidget(
      _host(
        const ProgressTrendCard(
          history: [
            ProgressPoint(date: '2026-07-30', percent: 40),
            ProgressPoint(date: '2026-07-31', percent: 55),
          ],
        ),
      ),
    );
    await tester.pump();

    expect(find.text('진행률 추이'), findsOneWidget);
    expect(find.byType(LineChart), findsOneWidget);
  });

  testWidgets('ProgressTrendCard: 빈 배열이면 빈 상태 안내', (tester) async {
    await tester.pumpWidget(_host(const ProgressTrendCard(history: [])));
    await tester.pump();

    expect(find.text('아직 학습 기록이 없어요'), findsOneWidget);
    expect(find.byType(LineChart), findsNothing);
  });
}
