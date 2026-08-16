import 'package:devpath_mobile/src/data/mobile_mock_fixtures.dart';
import 'package:devpath_mobile/src/features/learning/presentation/mobile_content_projection.dart';
import 'package:devpath_mobile/src/features/today/presentation/mobile_today_projection.dart';
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(
  theme: DpTheme.light(),
  home: Scaffold(body: child),
);

void main() {
  testWidgets('approved Today fixture uses the native production projection', (
    tester,
  ) async {
    final mission = CurrentMission.fromJson(mockCurrentMission());
    WeeklyTask? opened;

    await tester.pumpWidget(
      _host(
        MobileTodayProjection(
          mission: mission,
          onOpenContent: (task) => opened = task,
          onCompleteContentlessTask: (_) {},
          onRefresh: () {},
        ),
      ),
    );

    expect(mission.outcome, CurrentMissionOutcome.available);
    expect(mission.pathId, 101);
    expect(mission.weekNum, 1);
    expect(mission.tasks.map((task) => task.taskId), [1001, 1002]);
    expect(find.byType(DpMissionHeader), findsOneWidget);
    expect(find.text('1주차 · 읽기'), findsOneWidget);
    expect(find.text('Future/async-await 정리'), findsWidgets);
    expect(find.bySemanticsLabel('0/2 완료, 0%'), findsOneWidget);

    await tester.tap(find.text('학습 계속'));
    expect(opened?.taskId, 1001);
  });

  testWidgets(
    'approved content fixture uses the native production projection',
    (tester) async {
      final content = LearningContent.fromJson(
        Map<String, dynamic>.from(mockContent('future-async-await')),
      );
      var completions = 0;

      await tester.pumpWidget(
        _host(
          MobileContentProjection(
            content: content,
            scrollController: ScrollController(),
            onComplete: () => completions += 1,
          ),
        ),
      );

      expect(content.id, 1);
      expect(content.slug, 'future-async-await');
      expect(find.text('8분 · 이해하기 · 난이도 중급'), findsOneWidget);
      expect(find.text('#future'), findsOneWidget);
      expect(find.text('#async-await'), findsOneWidget);
      expect(find.text('완료로 표시'), findsOneWidget);

      await tester.tap(find.text('완료로 표시'));
      expect(completions, 1);
    },
  );
}
