import 'package:devpath_web/src/features/path/presentation/milestone_progress_card.dart';
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(
  theme: DpTheme.light(),
  home: Scaffold(body: child),
);

WeeklyTask _task({required bool done}) =>
    WeeklyTask(orderNum: 1, taskType: 'READ', title: 't', completed: done);

/// PathMilestone은 필수 필드가 많다 — 전부 채워야 컴파일된다.
PathMilestone _ms(int week, List<WeeklyTask> tasks) => PathMilestone(
  weekNum: week,
  title: '$week주차',
  goalDescription: '목표',
  estimatedHours: 5,
  whyThisOrder: '이유',
  expectedOutcome: '결과',
  tasks: tasks,
);

void main() {
  testWidgets('주차마다 완료율 막대를 하나씩 렌더한다', (tester) async {
    final milestones = [
      _ms(1, [_task(done: true), _task(done: true)]), // 100%
      _ms(2, [_task(done: true), _task(done: false)]), // 50%
      _ms(3, [_task(done: false), _task(done: false)]), // 0%
    ];

    await tester.pumpWidget(
      _host(MilestoneProgressCard(milestones: milestones)),
    );
    await tester.pumpAndSettle();

    final chart = tester.widget<BarChart>(find.byType(BarChart));
    expect(chart.data.barGroups.length, 3);
    expect(chart.data.barGroups[0].barRods.first.toY, 100);
    expect(chart.data.barGroups[1].barRods.first.toY, 50);
    expect(chart.data.barGroups[2].barRods.first.toY, 0);
    expect(chart.data.barGroups[0].barRods.first.color, DpColors.light.chart1);

    // 단일 계열이라 범례를 두지 않는다.
    expect(find.byType(DpChartLegend), findsNothing);
  });

  testWidgets('과제가 없는 주차는 0%로 센다', (tester) async {
    await tester.pumpWidget(
      _host(MilestoneProgressCard(milestones: [_ms(1, const [])])),
    );
    await tester.pumpAndSettle();

    final chart = tester.widget<BarChart>(find.byType(BarChart));
    expect(chart.data.barGroups.first.barRods.first.toY, 0);
  });

  testWidgets('마일스톤이 없으면 안내 문구를 렌더한다', (tester) async {
    await tester.pumpWidget(_host(const MilestoneProgressCard(milestones: [])));
    await tester.pumpAndSettle();

    expect(find.text('아직 학습 경로가 없어요'), findsOneWidget);
    expect(find.byType(BarChart), findsNothing);
  });
}
