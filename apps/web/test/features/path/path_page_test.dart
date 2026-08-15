import 'dart:async';
import 'dart:convert';

import 'package:devpath_web/src/app/app_config.dart';
import 'package:devpath_web/src/features/dashboard/application/current_mission_controller.dart';
import 'package:devpath_web/src/features/auth/application/auth_controller.dart';
import 'package:devpath_web/src/features/auth/state/auth_state.dart';
import 'package:devpath_web/src/features/path/application/path_controller.dart';
import 'package:devpath_web/src/features/path/data/path_sse_source.dart';
import 'package:devpath_web/src/features/path/presentation/path_page.dart';
import 'package:devpath_web/src/providers/api_providers.dart';
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Stream<SseEvent> _emit(List<String> stages) async* {
  for (final s in stages) {
    yield SseEvent(
      event: 'progress',
      data: jsonEncode({
        'stage': s,
        'progress': s == 'done' ? 1.0 : 0.5,
        'message': s,
        'pathId': s == 'done' ? 101 : null,
      }),
    );
  }
}

Stream<SseEvent> _emitThenError(List<String> stages) async* {
  yield* _emit(stages);
  throw Exception('끊김');
}

Widget _host(ProviderContainer c) => UncontrolledProviderScope(
  container: c,
  child: MaterialApp(theme: DpTheme.light(), home: const PathPage()),
);

({Widget host, GoRouter router}) _routerHost(ProviderContainer c) {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const PathPage()),
      GoRoute(
        path: '/content/:id',
        builder: (_, state) => Text('legacy ${state.pathParameters['id']}'),
      ),
      GoRoute(
        path: '/mission/:taskId/content/:contentId',
        builder: (_, state) => Text(
          'mission ${state.pathParameters['taskId']} '
          'content ${state.pathParameters['contentId']}',
        ),
      ),
    ],
  );
  return (
    host: UncontrolledProviderScope(
      container: c,
      child: MaterialApp.router(theme: DpTheme.light(), routerConfig: router),
    ),
    router: router,
  );
}

class _AuthedAuthController extends AuthController {
  @override
  AuthState build() => const AuthAuthenticated(
    User(
      id: '73',
      email: 'e2e@devpath.local',
      nickname: 'E2E',
      role: UserRole.learner,
      onboardingStatus: OnboardingStatus.done,
      consentStatus: ConsentStatus.done,
    ),
  );
}

class _PendingPathController extends PathController {
  var loadCalls = 0;
  final pending = Completer<void>();

  @override
  PathState build() => const PathState();

  @override
  Future<void> loadOrStart() {
    loadCalls += 1;
    return pending.future;
  }
}

class _ReadyMissionController extends CurrentMissionController {
  _ReadyMissionController(this.mission);

  final CurrentMission mission;
  var loadCalls = 0;
  var refreshCalls = 0;

  @override
  CurrentMissionState build() => CurrentMissionState(mission: mission);

  @override
  Future<CurrentMission?> load({bool force = false}) async {
    loadCalls += 1;
    return mission;
  }

  @override
  Future<CurrentMission?> invalidateAndRefetch() async {
    refreshCalls += 1;
    return mission;
  }
}

class _GeneratingPathController extends PathController {
  @override
  PathState build() =>
      const PathState(phase: PathPhase.streaming, current: '경로 생성 중');

  void finish() {
    state = PathState(phase: PathPhase.complete, result: _pathPlan());
  }
}

class _CompletedPathController extends PathController {
  _CompletedPathController({this.initialPhase = PathPhase.complete});

  final PathPhase initialPhase;
  var loadCalls = 0;

  @override
  PathState build() => PathState(
    phase: initialPhase,
    result: initialPhase == PathPhase.complete ? _pathPlan() : null,
  );

  @override
  Future<void> loadOrStart() async {
    loadCalls += 1;
  }

  void finish() {
    state = PathState(phase: PathPhase.complete, result: _pathPlan());
  }
}

class _PartialPathController extends PathController {
  var retryCalls = 0;

  @override
  PathState build() => const PathState(
    phase: PathPhase.partial,
    completed: ['진단 분석'],
    error: '상세 생성 중 연결이 끊겼어요',
  );

  @override
  Future<void> loadOrStart() async {
    retryCalls += 1;
  }
}

class _FailedPathController extends PathController {
  @override
  PathState build() =>
      const PathState(phase: PathPhase.failed, error: '상세 조회에 실패했어요');

  @override
  Future<void> loadOrStart() async {}
}

void main() {
  testWidgets('flag ON은 current mission과 전체 path를 병렬 시작하고 mission을 먼저 그린다', (
    tester,
  ) async {
    final path = _PendingPathController();
    final mission = _ReadyMissionController(_availableMission());
    final c = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          const AppConfig(
            baseUrl: 'https://mock.devpath.ai',
            useMock: true,
            missionSpineEnabled: true,
          ),
        ),
        authControllerProvider.overrideWith(_AuthedAuthController.new),
        pathControllerProvider.overrideWith(() => path),
        currentMissionControllerProvider.overrideWith(() => mission),
      ],
    );
    addTearDown(() {
      if (!path.pending.isCompleted) path.pending.complete();
      c.dispose();
    });

    await tester.pumpWidget(_host(c));
    await tester.pump();

    expect(path.loadCalls, 1);
    expect(mission.loadCalls, 1);
    expect(find.text('현재 3주차 과제'), findsWidgets);
    expect(find.byType(DpMissionHeader), findsOneWidget);
  });

  testWidgets('flag ON Path CTA는 taskId를 버리지 않고 canonical workspace를 push한다', (
    tester,
  ) async {
    final path = _PendingPathController();
    final mission = _ReadyMissionController(_availableMission());
    final c = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          const AppConfig(
            baseUrl: 'https://mock.devpath.ai',
            useMock: true,
            missionSpineEnabled: true,
          ),
        ),
        authControllerProvider.overrideWith(_AuthedAuthController.new),
        pathControllerProvider.overrideWith(() => path),
        currentMissionControllerProvider.overrideWith(() => mission),
      ],
    );
    final routed = _routerHost(c);
    addTearDown(() {
      if (!path.pending.isCompleted) path.pending.complete();
      routed.router.dispose();
      c.dispose();
    });

    await tester.pumpWidget(routed.host);
    await tester.pump();
    await tester.tap(find.text('미션 열기'));
    await tester.pumpAndSettle();

    expect(
      routed.router.routerDelegate.state.uri.toString(),
      '/mission/302/content/303',
    );
    expect(find.text('mission 302 content 303'), findsOneWidget);
    expect(routed.router.canPop(), isTrue);

    routed.router.pop();
    await tester.pumpAndSettle();
    expect(find.byType(PathPage), findsOneWidget);
  });

  testWidgets('flag OFF는 legacy Path만 시작하고 current mission을 요청하지 않는다', (
    tester,
  ) async {
    final path = _PendingPathController();
    final mission = _ReadyMissionController(_availableMission());
    final c = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          const AppConfig(
            baseUrl: 'https://mock.devpath.ai',
            useMock: true,
            missionSpineEnabled: false,
          ),
        ),
        authControllerProvider.overrideWith(_AuthedAuthController.new),
        pathControllerProvider.overrideWith(() => path),
        currentMissionControllerProvider.overrideWith(() => mission),
      ],
    );
    addTearDown(() {
      if (!path.pending.isCompleted) path.pending.complete();
      c.dispose();
    });

    await tester.pumpWidget(_host(c));
    await tester.pump();

    expect(path.loadCalls, 1);
    expect(mission.loadCalls, 0);
    expect(find.byType(DpMissionHeader), findsNothing);
  });

  testWidgets('새 경로 생성 완료 뒤 authoritative current mission만 다시 읽는다', (
    tester,
  ) async {
    final path = _GeneratingPathController();
    final mission = _ReadyMissionController(_noActiveMission());
    final c = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          const AppConfig(
            baseUrl: 'https://mock.devpath.ai',
            useMock: true,
            missionSpineEnabled: true,
          ),
        ),
        authControllerProvider.overrideWith(_AuthedAuthController.new),
        pathControllerProvider.overrideWith(() => path),
        currentMissionControllerProvider.overrideWith(() => mission),
      ],
    );
    addTearDown(c.dispose);

    await tester.pumpWidget(_host(c));
    await tester.pump();
    expect(mission.loadCalls, 1);

    path.finish();
    await tester.pump();
    await tester.pump();

    expect(mission.refreshCalls, 1);
  });

  testWidgets('완료 경로를 들고 진입하고 cached NO_ACTIVE_PATH면 한 번만 재조회한다', (
    tester,
  ) async {
    final path = _CompletedPathController();
    final mission = _ReadyMissionController(_noActiveMission());
    final c = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          const AppConfig(
            baseUrl: 'https://mock.devpath.ai',
            useMock: true,
            missionSpineEnabled: true,
          ),
        ),
        authControllerProvider.overrideWith(_AuthedAuthController.new),
        pathControllerProvider.overrideWith(() => path),
        currentMissionControllerProvider.overrideWith(() => mission),
      ],
    );
    addTearDown(c.dispose);

    await tester.pumpWidget(_host(c));
    await tester.pump();
    await tester.pump();

    expect(path.loadCalls, 0);
    expect(mission.loadCalls, 1);
    expect(mission.refreshCalls, 1);
  });

  testWidgets('기존 경로 idle→complete도 cached NO_ACTIVE_PATH를 한 번만 재조회한다', (
    tester,
  ) async {
    final path = _CompletedPathController(initialPhase: PathPhase.idle);
    final mission = _ReadyMissionController(_noActiveMission());
    final c = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          const AppConfig(
            baseUrl: 'https://mock.devpath.ai',
            useMock: true,
            missionSpineEnabled: true,
          ),
        ),
        authControllerProvider.overrideWith(_AuthedAuthController.new),
        pathControllerProvider.overrideWith(() => path),
        currentMissionControllerProvider.overrideWith(() => mission),
      ],
    );
    addTearDown(c.dispose);

    await tester.pumpWidget(_host(c));
    await tester.pump();
    path.finish();
    await tester.pump();
    await tester.pump();

    expect(path.loadCalls, 1);
    expect(mission.refreshCalls, 1);
  });

  testWidgets('사용 가능한 미션은 상세 경로 중단에도 유지되고 보조 재시도를 제공한다', (tester) async {
    final path = _PartialPathController();
    final mission = _ReadyMissionController(_availableMission());
    final c = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          const AppConfig(
            baseUrl: 'https://mock.devpath.ai',
            useMock: true,
            missionSpineEnabled: true,
          ),
        ),
        authControllerProvider.overrideWith(_AuthedAuthController.new),
        pathControllerProvider.overrideWith(() => path),
        currentMissionControllerProvider.overrideWith(() => mission),
      ],
    );
    addTearDown(c.dispose);

    await tester.pumpWidget(_host(c));
    await tester.pump();

    expect(find.byType(DpMissionHeader), findsOneWidget);
    expect(find.byType(DpNextActionBand), findsOneWidget);
    expect(find.text('경로 상세를 불러오지 못했어요'), findsOneWidget);
    expect(find.text('경로 상세 다시 확인'), findsOneWidget);

    await tester.ensureVisible(find.text('경로 상세 다시 확인'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('경로 상세 다시 확인'));
    await tester.pump();
    expect(path.retryCalls, 1);
  });

  testWidgets('사용 가능한 미션은 상세 경로 조회 실패에도 유일 primary를 유지한다', (tester) async {
    final path = _FailedPathController();
    final mission = _ReadyMissionController(_availableMission());
    final c = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          const AppConfig(
            baseUrl: 'https://mock.devpath.ai',
            useMock: true,
            missionSpineEnabled: true,
          ),
        ),
        authControllerProvider.overrideWith(_AuthedAuthController.new),
        pathControllerProvider.overrideWith(() => path),
        currentMissionControllerProvider.overrideWith(() => mission),
      ],
    );
    addTearDown(c.dispose);

    await tester.pumpWidget(_host(c));
    await tester.pump();

    expect(find.byType(DpMissionHeader), findsOneWidget);
    expect(find.byType(DpNextActionBand), findsOneWidget);
    expect(find.text('경로 상세를 불러오지 못했어요'), findsOneWidget);
    expect(find.text('상세 조회에 실패했어요'), findsOneWidget);
    expect(find.text('경로 상세 다시 확인'), findsOneWidget);
  });

  testWidgets('완료 시 12주 타임라인과 이번 주 과제를 렌더', (tester) async {
    final c = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(_AuthedAuthController.new),
        pathSseConnectProvider.overrideWithValue(() => _emit(kPathStages)),
      ],
    );
    addTearDown(c.dispose);

    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();

    expect(c.read(pathControllerProvider).phase, PathPhase.complete);
    expect(find.text('Stream 구독 실습'), findsOneWidget); // 이번 주 과제

    // 진단 요약에 강점/약점 소제목이 추가되며 늘어난 높이 때문에 12주
    // 타임라인의 1주차 항목이 초기 뷰포트 밖으로 밀렸다(2026-08-03).
    // path_plan_view_test.dart와 같은 패턴으로 스크롤 후 확인한다.
    // 헤더도 함께 스크롤되는 문서형 전환(Task 10)으로 화면 최상위 스크롤
    // 컨테이너가 ListView에서 CustomScrollView로 바뀌었다.
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.textContaining('비동기 기초'), findsWidgets); // week1 제목
  });

  testWidgets('중단 시 "다시 생성" 노출', (tester) async {
    final c = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(_AuthedAuthController.new),
        pathSseConnectProvider.overrideWithValue(
          () => _emitThenError(['collecting', 'generating']),
        ),
      ],
    );
    addTearDown(c.dispose);

    await c.read(pathControllerProvider.notifier).start();
    await tester.pumpWidget(_host(c));
    await tester.pump(const Duration(milliseconds: 100));

    expect(c.read(pathControllerProvider).phase, PathPhase.partial);
    expect(find.text('다시 생성'), findsOneWidget);
    expect(find.byType(DpSseStageView), findsOneWidget); // 완료 단계 보존 표시

    // §9.2 PARTIAL: 완료 단계만이 아니라 kPathStageLabels 전체(미완 스켈레톤 포함)를 표시.
    final stageView = tester.widget<DpSseStageView>(
      find.byType(DpSseStageView),
    );
    expect(stageView.stages, kPathStageLabels); // 3단계 전부(미완 단계도 노출)
    expect(stageView.currentIndex, 2); // collecting·generating 완료
  });
}

CurrentMission _availableMission() => CurrentMission.fromJson({
  'outcome': 'AVAILABLE',
  'pathId': 101,
  'weekNum': 3,
  'tasks': [
    {
      'taskId': 302,
      'orderNum': 1,
      'taskType': 'PRACTICE',
      'title': '현재 3주차 과제',
      'required': true,
      'contentId': 303,
      'contentSlug': 'current-week-three',
      'completed': false,
      'completedAt': null,
    },
  ],
  'nextTask': {
    'taskId': 302,
    'orderNum': 1,
    'taskType': 'PRACTICE',
    'title': '현재 3주차 과제',
    'required': true,
    'contentId': 303,
    'contentSlug': 'current-week-three',
    'completed': false,
    'completedAt': null,
  },
  'pathCompleted': false,
});

CurrentMission _noActiveMission() => CurrentMission.fromJson({
  'outcome': 'NO_ACTIVE_PATH',
  'pathId': null,
  'weekNum': null,
  'tasks': <Map<String, Object?>>[],
  'nextTask': null,
  'pathCompleted': false,
});

LearningPath _pathPlan() => LearningPath.fromJson({
  'pathId': 101,
  'track': 'BACKEND',
  'totalWeeks': 12,
  'rationale': '경로 근거',
  'milestones': [
    {
      'weekNum': 1,
      'title': '첫 주차',
      'goalDescription': '목표',
      'targetSkills': <String>[],
      'estimatedHours': 3,
      'whyThisOrder': '순서',
      'expectedOutcome': '결과',
      'locked': false,
      'tasks': <Map<String, Object?>>[],
    },
  ],
});
