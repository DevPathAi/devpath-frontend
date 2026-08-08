import 'package:devpath_web/src/features/path/presentation/milestone_progress_card.dart';
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {double? width}) => MaterialApp(
  theme: DpTheme.light(),
  home: Scaffold(
    body: width == null ? child : SizedBox(width: width, child: child),
  ),
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

  testWidgets('진행이 0%인 주차도 배경 트랙으로 존재를 보인다', (tester) async {
    // ★육안 확인에서 잡은 결함★ 경로를 막 만든 사용자는 12주가 전부 0%다.
    // 막대만 그리면 높이 0이라 화면에 **아무것도 보이지 않고**, 제목과 X축 숫자만
    // 남아 「차트가 고장났다」로 읽힌다. 도넛이 미완료를 면으로 그리는 것과 같은
    // 원칙으로(스펙 §4) 배경 트랙을 깐다.
    final milestones = [
      for (var w = 1; w <= 3; w++) _ms(w, [_task(done: false)]),
    ];

    await tester.pumpWidget(
      _host(MilestoneProgressCard(milestones: milestones)),
    );
    await tester.pumpAndSettle();

    final chart = tester.widget<BarChart>(find.byType(BarChart));
    for (final g in chart.data.barGroups) {
      final rod = g.barRods.first;
      expect(rod.toY, 0);
      expect(rod.backDrawRodData.show, isTrue);
      expect(rod.backDrawRodData.toY, 100);
      expect(rod.backDrawRodData.color, DpColors.light.surfaceMuted);
    }
  });

  testWidgets('12주 경로를 좁은 폭에서도 오버플로 없이 렌더한다', (tester) async {
    // 목 픽스처도 12주지만 **캡처는 넓은 폭 위주라 좁은 폭의 밀집도를 보지 못한다.**
    // 막대 12개가 360px에 들어가는지와 오버플로 부재를 여기서 잠근다.
    final milestones = [
      for (var w = 1; w <= 12; w++) _ms(w, [_task(done: w <= 4)]),
    ];

    await tester.pumpWidget(
      _host(MilestoneProgressCard(milestones: milestones), width: 360),
    );
    await tester.pumpAndSettle();

    final chart = tester.widget<BarChart>(find.byType(BarChart));
    expect(chart.data.barGroups.length, 12);
    expect(tester.takeException(), isNull);
  });

  testWidgets('마일스톤이 없으면 안내 문구를 렌더한다', (tester) async {
    await tester.pumpWidget(_host(const MilestoneProgressCard(milestones: [])));
    await tester.pumpAndSettle();

    expect(find.text('아직 학습 경로가 없어요'), findsOneWidget);
    expect(find.byType(BarChart), findsNothing);
  });
}
