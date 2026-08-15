import 'package:devpath_web/src/features/dashboard/application/current_mission_controller.dart';
import 'package:devpath_web/src/features/path/presentation/mission_path_plan_view.dart';
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host({
  required CurrentMissionState missionState,
  LearningPath? plan,
  ValueChanged<int>? onOpenContent,
  ValueChanged<int>? onCompleteContentless,
}) => MaterialApp(
  theme: DpTheme.light(),
  home: Scaffold(
    body: SingleChildScrollView(
      child: MissionPathPlanView(
        missionState: missionState,
        plan: plan,
        onRetryMission: () {},
        onOpenContent: onOpenContent ?? (_) {},
        onCompleteContentless: onCompleteContentless ?? (_) {},
      ),
    ),
  ),
);

void main() {
  testWidgets('서버가 지정한 3주차를 첫 milestone 대신 현재 hero로 사용한다', (tester) async {
    await tester.pumpWidget(
      _host(
        missionState: CurrentMissionState(mission: _availableMission()),
        plan: _path(),
      ),
    );

    final header = tester.widget<DpMissionHeader>(find.byType(DpMissionHeader));
    expect(header.eyebrow, '3주차 · 미션 2');
    expect(header.title, '현재 3주차 과제');
    expect(header.why, '3주차를 지금 배우는 서버 경로 근거');
    expect(find.text('1주차를 지금 배우는 근거'), findsNothing);
    expect(find.text('다음 잠금 해제 · 5주차 다음 단계'), findsOneWidget);
  });

  testWidgets('pathId나 weekNum이 맞지 않으면 상세를 추론하지 않는다', (tester) async {
    final mismatchedPlan = _path(pathId: 999);

    await tester.pumpWidget(
      _host(
        missionState: CurrentMissionState(mission: _availableMission()),
        plan: mismatchedPlan,
      ),
    );

    final header = tester.widget<DpMissionHeader>(find.byType(DpMissionHeader));
    expect(header.why, '서버가 정한 이번 주의 첫 미완료 과제예요.');
    expect(find.text('현재 미션과 경로 상세가 아직 맞지 않아요.'), findsOneWidget);
    expect(find.text('3주차를 지금 배우는 서버 경로 근거'), findsNothing);
  });

  testWidgets('미래 주차 상세는 기본 접힘이며 사용자가 열 때만 보인다', (tester) async {
    await tester.pumpWidget(
      _host(
        missionState: CurrentMissionState(mission: _availableMission()),
        plan: _path(),
      ),
    );

    expect(find.text('앞으로의 주차'), findsOneWidget);
    expect(find.text('5주차 다음 단계'), findsOneWidget);
    expect(find.text('미래 상세 목표'), findsNothing);

    await tester.ensureVisible(find.text('5주차 다음 단계'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('5주차 다음 단계'));
    await tester.pumpAndSettle();

    expect(find.text('미래 상세 목표'), findsOneWidget);
  });

  testWidgets('현재 content task와 contentless task의 행동 경계를 지킨다', (tester) async {
    int? openedContent;
    await tester.pumpWidget(
      _host(
        missionState: CurrentMissionState(mission: _availableMission()),
        plan: _path(),
        onOpenContent: (id) => openedContent = id,
      ),
    );

    await tester.tap(find.text('미션 열기'));
    expect(openedContent, 303);

    int? completedTask;
    await tester.pumpWidget(
      _host(
        missionState: CurrentMissionState(
          mission: _availableMission(contentless: true),
        ),
        plan: _path(),
        onCompleteContentless: (id) => completedTask = id,
      ),
    );

    await tester.tap(find.text('미션 완료'));
    expect(completedTask, 302);
  });

  testWidgets('다음 unlock은 현재 뒤의 이미 완료된 task를 건너뛴다', (tester) async {
    await tester.pumpWidget(
      _host(
        missionState: CurrentMissionState(
          mission: _missionWithOutOfOrderCompletion(),
        ),
      ),
    );

    expect(find.text('다음 잠금 해제 · 아직 남은 과제'), findsOneWidget);
    expect(find.text('다음 잠금 해제 · 이미 완료한 뒤 과제'), findsNothing);
  });

  testWidgets('완료 경로는 current step 없는 spine 대신 완료 근거를 보여준다', (tester) async {
    await tester.pumpWidget(
      _host(
        missionState: CurrentMissionState(mission: _completedMission()),
        plan: _path(),
      ),
    );

    expect(find.byType(DpProgressSpine), findsNothing);
    expect(find.text('12주 경로를 모두 완료했어요'), findsOneWidget);
    expect(find.text('완료한 미션 2개'), findsOneWidget);
  });

  testWidgets('320px와 200% 글자에서도 primary action 하나로 overflow 없이 읽힌다', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });

    await tester.pumpWidget(
      _host(
        missionState: CurrentMissionState(mission: _availableMission()),
        plan: _path(),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(DpNextActionBand), findsOneWidget);
    expect(find.text('미션 열기'), findsOneWidget);
  });
}

CurrentMission _availableMission({bool contentless = false}) =>
    CurrentMission.fromJson({
      'outcome': 'AVAILABLE',
      'pathId': 101,
      'weekNum': 3,
      'tasks': [
        {
          'taskId': 301,
          'orderNum': 1,
          'taskType': 'READ',
          'title': '완료한 3주차 과제',
          'required': true,
          'contentId': 301,
          'contentSlug': 'done-week-three',
          'completed': true,
          'completedAt': '2026-08-15T00:00:00Z',
        },
        {
          'taskId': 302,
          'orderNum': 2,
          'taskType': contentless ? 'QUIZ' : 'PRACTICE',
          'title': '현재 3주차 과제',
          'required': true,
          'contentId': contentless ? null : 303,
          'contentSlug': contentless ? null : 'current-week-three',
          'completed': false,
          'completedAt': null,
        },
      ],
      'nextTask': {
        'taskId': 302,
        'orderNum': 2,
        'taskType': contentless ? 'QUIZ' : 'PRACTICE',
        'title': '현재 3주차 과제',
        'required': true,
        'contentId': contentless ? null : 303,
        'contentSlug': contentless ? null : 'current-week-three',
        'completed': false,
        'completedAt': null,
      },
      'pathCompleted': false,
    });

CurrentMission _completedMission() => CurrentMission.fromJson({
  'outcome': 'PATH_COMPLETED',
  'pathId': 101,
  'weekNum': 3,
  'tasks': [
    {
      'taskId': 301,
      'orderNum': 1,
      'taskType': 'READ',
      'title': '완료 1',
      'required': true,
      'contentId': 301,
      'contentSlug': 'done-one',
      'completed': true,
      'completedAt': '2026-08-14T00:00:00Z',
    },
    {
      'taskId': 302,
      'orderNum': 2,
      'taskType': 'QUIZ',
      'title': '완료 2',
      'required': true,
      'contentId': null,
      'contentSlug': null,
      'completed': true,
      'completedAt': '2026-08-15T00:00:00Z',
    },
  ],
  'nextTask': null,
  'pathCompleted': true,
});

CurrentMission _missionWithOutOfOrderCompletion() => CurrentMission.fromJson({
  'outcome': 'AVAILABLE',
  'pathId': 101,
  'weekNum': 3,
  'tasks': [
    {
      'taskId': 301,
      'orderNum': 1,
      'taskType': 'READ',
      'title': '현재 과제',
      'required': true,
      'contentId': 301,
      'contentSlug': 'current',
      'completed': false,
      'completedAt': null,
    },
    {
      'taskId': 302,
      'orderNum': 2,
      'taskType': 'QUIZ',
      'title': '이미 완료한 뒤 과제',
      'required': false,
      'contentId': null,
      'contentSlug': null,
      'completed': true,
      'completedAt': '2026-08-14T00:00:00Z',
    },
    {
      'taskId': 303,
      'orderNum': 3,
      'taskType': 'PRACTICE',
      'title': '아직 남은 과제',
      'required': true,
      'contentId': 303,
      'contentSlug': 'remaining',
      'completed': false,
      'completedAt': null,
    },
  ],
  'nextTask': {
    'taskId': 301,
    'orderNum': 1,
    'taskType': 'READ',
    'title': '현재 과제',
    'required': true,
    'contentId': 301,
    'contentSlug': 'current',
    'completed': false,
    'completedAt': null,
  },
  'pathCompleted': false,
});

LearningPath _path({int pathId = 101}) => LearningPath.fromJson({
  'pathId': pathId,
  'track': 'BACKEND',
  'totalWeeks': 12,
  'rationale': '전체 경로 근거',
  'diagnosis': {
    'diagnosedLevel': 'MID',
    'strengthConcepts': ['HTTP'],
    'weaknessConcepts': ['트랜잭션'],
  },
  'milestones': [
    {
      'weekNum': 1,
      'title': '1주차 기초',
      'goalDescription': '이미 완료한 목표',
      'targetSkills': ['기초'],
      'estimatedHours': 3,
      'whyThisOrder': '1주차를 지금 배우는 근거',
      'expectedOutcome': '기초 완료',
      'locked': false,
      'tasks': <Map<String, Object?>>[],
    },
    {
      'weekNum': 3,
      'title': '3주차 현재 단계',
      'goalDescription': '현재 주차 목표',
      'targetSkills': ['현재'],
      'estimatedHours': 4,
      'whyThisOrder': '3주차를 지금 배우는 서버 경로 근거',
      'expectedOutcome': '현재 주차 완료 기준',
      'locked': false,
      'tasks': <Map<String, Object?>>[],
    },
    {
      'weekNum': 5,
      'title': '다음 단계',
      'goalDescription': '미래 상세 목표',
      'targetSkills': ['다음'],
      'estimatedHours': 5,
      'whyThisOrder': '현재 단계 다음에 진행합니다.',
      'expectedOutcome': '다음 단계 완료',
      'locked': true,
      'tasks': <Map<String, Object?>>[],
    },
  ],
});
