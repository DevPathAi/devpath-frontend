import 'dart:async';

import 'package:devpath_web/src/app/app_config.dart';
import 'package:devpath_web/src/features/ads/data/ads_source.dart';
import 'package:devpath_web/src/features/ads/presentation/ad_slot_widget.dart';
import 'package:devpath_web/src/features/dashboard/application/current_mission_controller.dart';
import 'package:devpath_web/src/features/dashboard/application/dashboard_controller.dart';
import 'package:devpath_web/src/features/dashboard/presentation/dashboard_page.dart';
import 'package:devpath_web/src/features/dashboard/state/dashboard_state.dart';
import 'package:devpath_web/src/providers/api_providers.dart';
import 'package:dio/dio.dart';
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

AppConfig _config({required bool missionSpineEnabled}) => AppConfig(
  baseUrl: 'https://mock.devpath.ai',
  useMock: true,
  missionSpineEnabled: missionSpineEnabled,
);

CurrentMission _mission(
  String outcome, {
  String availableTitle = 'JPA 트랜잭션 경계 읽기',
}) {
  if (outcome == 'NO_ACTIVE_PATH') {
    return CurrentMission.fromJson({
      'outcome': outcome,
      'pathId': null,
      'weekNum': null,
      'tasks': <Object?>[],
      'nextTask': null,
      'pathCompleted': false,
    });
  }
  if (outcome == 'MALFORMED_PATH') {
    return CurrentMission.fromJson({'outcome': outcome});
  }

  final completed = outcome == 'PATH_COMPLETED';
  final task = <String, Object?>{
    'taskId': 302,
    'orderNum': 1,
    'taskType': 'READ',
    'title': completed ? '마지막 미션' : availableTitle,
    'required': true,
    'contentId': 77,
    'contentSlug': 'jpa-transaction-boundary',
    'completed': completed,
    'completedAt': completed ? '2026-08-15T02:00:00.000Z' : null,
  };
  return CurrentMission.fromJson({
    'outcome': outcome,
    'pathId': 301,
    'weekNum': 4,
    'tasks': [task],
    'nextTask': completed ? null : task,
    'pathCompleted': completed,
  });
}

final class _DashboardClient implements ApiClient {
  _DashboardClient({this.delayed = false, this.onStart});

  final bool delayed;
  final VoidCallback? onStart;
  final dashboardCompleter = Completer<Map<String, dynamic>>();
  var dashboardCalls = 0;

  @override
  Future<T> get<T>(String path, {Map<String, dynamic>? query}) {
    if (path != '/dashboard/me') throw StateError('unexpected GET $path');
    dashboardCalls += 1;
    onStart?.call();
    if (!delayed && !dashboardCompleter.isCompleted) {
      dashboardCompleter.complete({
        'streakDays': 7,
        'progressPercent': 62,
        'nextTaskTitle': 'legacy next task',
        'badges': <String>['첫 경로'],
        'completedContentCount': 12,
      });
    }
    return dashboardCompleter.future as Future<T>;
  }

  @override
  Future<T> post<T>(String path, {Object? body, Map<String, dynamic>? query}) =>
      throw UnimplementedError();

  @override
  Future<T> put<T>(String path, {Object? body, Map<String, dynamic>? query}) =>
      throw UnimplementedError();

  @override
  Future<T> delete<T>(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) => throw UnimplementedError();

  @override
  Stream<SseEvent> sse(String path, {Object? body}) =>
      throw UnimplementedError();

  @override
  Future<T> postMultipart<T>(
    String path, {
    required List<int> bytes,
    required String filename,
    String field = 'file',
    String? contentType,
  }) => throw UnimplementedError();

  @override
  Dio get dio => throw UnimplementedError();
}

final class _QueuedDashboardClient implements ApiClient {
  _QueuedDashboardClient(this.responses);

  final List<Future<Map<String, dynamic>>> responses;
  var dashboardCalls = 0;

  @override
  Future<T> get<T>(String path, {Map<String, dynamic>? query}) {
    if (path != '/dashboard/me') throw StateError('unexpected GET $path');
    final response = responses[dashboardCalls];
    dashboardCalls += 1;
    return response as Future<T>;
  }

  @override
  Future<T> post<T>(String path, {Object? body, Map<String, dynamic>? query}) =>
      throw UnimplementedError();

  @override
  Future<T> put<T>(String path, {Object? body, Map<String, dynamic>? query}) =>
      throw UnimplementedError();

  @override
  Future<T> delete<T>(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) => throw UnimplementedError();

  @override
  Stream<SseEvent> sse(String path, {Object? body}) =>
      throw UnimplementedError();

  @override
  Future<T> postMultipart<T>(
    String path, {
    required List<int> bytes,
    required String filename,
    String field = 'file',
    String? contentType,
  }) => throw UnimplementedError();

  @override
  Dio get dio => throw UnimplementedError();
}

Map<String, dynamic> _dashboardSummary(String owner, int streakDays) => {
  'streakDays': streakDays,
  'progressPercent': streakDays,
  'nextTaskTitle': '$owner next task',
  'badges': <String>['$owner badge'],
  'completedContentCount': streakDays,
};

final class _DashboardMissionApi extends LearningPathApi {
  _DashboardMissionApi(this.responses, {this.onStart})
    : super(ApiClient(Dio()));

  final List<Future<CurrentMission>> responses;
  final VoidCallback? onStart;
  var calls = 0;

  @override
  Future<CurrentMission> currentMission() {
    onStart?.call();
    final response = responses[calls];
    calls += 1;
    return response;
  }
}

class _DashboardOwnerKeyController extends Notifier<String?> {
  @override
  String? build() => 'user-a';

  void changeTo(String? ownerKey) => state = ownerKey;
}

final _dashboardOwnerKeyProvider =
    NotifierProvider<_DashboardOwnerKeyController, String?>(
      _DashboardOwnerKeyController.new,
    );

Future<GoRouter> _pumpDashboard(
  WidgetTester tester, {
  required bool enabled,
  required _DashboardMissionApi missionApi,
  required ApiClient dashboardClient,
  bool dynamicOwner = false,
}) async {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const DashboardPage()),
      GoRoute(path: '/path', builder: (_, _) => const Text('path page')),
      GoRoute(
        path: '/diagnostic',
        builder: (_, _) => const Text('diagnostic page'),
      ),
      GoRoute(
        path: '/content/:id',
        builder: (_, state) => Text('content ${state.pathParameters['id']}'),
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
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(
          _config(missionSpineEnabled: enabled),
        ),
        apiClientProvider.overrideWithValue(dashboardClient),
        learningPathApiProvider.overrideWithValue(missionApi),
        currentMissionOwnerKeyProvider.overrideWith(
          (ref) => dynamicOwner
              ? ref.watch(_dashboardOwnerKeyProvider)
              : 'dashboard-user',
        ),
        adFetchProvider.overrideWithValue((_) async => null),
      ],
      child: MaterialApp.router(theme: DpTheme.light(), routerConfig: router),
    ),
  );
  await tester.pump();
  await tester.pump();
  return router;
}

void main() {
  testWidgets('flag ON 첫 frame은 실패가 아니라 Today loading 상태다', (tester) async {
    final pendingMission = Completer<CurrentMission>();
    await _pumpDashboard(
      tester,
      enabled: true,
      missionApi: _DashboardMissionApi([pendingMission.future]),
      dashboardClient: _DashboardClient(delayed: true),
    );

    expect(find.text('오늘의 미션을 불러오는 중'), findsOneWidget);
    expect(find.text('오늘의 미션을 불러오지 못했어요'), findsNothing);
  });

  testWidgets('flag OFF는 legacy 대시보드를 유지하고 this-week를 호출하지 않는다', (
    tester,
  ) async {
    final missionApi = _DashboardMissionApi([
      Future.value(_mission('AVAILABLE')),
    ]);
    final dashboardClient = _DashboardClient();

    await _pumpDashboard(
      tester,
      enabled: false,
      missionApi: missionApi,
      dashboardClient: dashboardClient,
    );
    await tester.pumpAndSettle();

    expect(missionApi.calls, 0);
    expect(find.text('대시보드'), findsOneWidget);
    expect(find.text('이어서 학습'), findsOneWidget);
    expect(find.byKey(const ValueKey('today-mission-section')), findsNothing);
  });

  testWidgets('flag ON은 지연된 지표와 독립적으로 Today를 먼저 렌더하고 광고를 마지막에 둔다', (
    tester,
  ) async {
    final missionApi = _DashboardMissionApi([
      Future.value(_mission('AVAILABLE')),
    ]);
    final dashboardClient = _DashboardClient(delayed: true);

    await _pumpDashboard(
      tester,
      enabled: true,
      missionApi: missionApi,
      dashboardClient: dashboardClient,
    );

    expect(find.text('JPA 트랜잭션 경계 읽기'), findsOneWidget);
    expect(find.byType(DpMissionHeader), findsOneWidget);
    expect(find.byKey(const ValueKey('today-mission-section')), findsOneWidget);
    expect(find.byKey(const ValueKey('today-metrics-loading')), findsOneWidget);
    expect(find.byKey(const ValueKey('today-ad-section')), findsOneWidget);
    expect(find.byType(AdSlotWidget), findsOneWidget);

    final scroll = tester.widget<CustomScrollView>(
      find.byType(CustomScrollView),
    );
    final missionIndex = scroll.slivers.indexWhere(
      (sliver) => sliver.key == const ValueKey('today-mission-section'),
    );
    final metricsIndex = scroll.slivers.indexWhere(
      (sliver) => sliver.key == const ValueKey('today-metrics-loading'),
    );
    final adIndex = scroll.slivers.indexWhere(
      (sliver) => sliver.key == const ValueKey('today-ad-section'),
    );
    expect(missionIndex, greaterThanOrEqualTo(0));
    expect(metricsIndex, greaterThan(missionIndex));
    expect(adIndex, greaterThan(metricsIndex));
  });

  testWidgets('flag ON은 mission을 metrics보다 먼저 시작하고 둘을 병렬로 유지한다', (
    tester,
  ) async {
    final starts = <String>[];
    final mission = Completer<CurrentMission>();
    final missionApi = _DashboardMissionApi([
      mission.future,
    ], onStart: () => starts.add('mission'));
    final dashboardClient = _DashboardClient(
      delayed: true,
      onStart: () => starts.add('metrics'),
    );

    await _pumpDashboard(
      tester,
      enabled: true,
      missionApi: missionApi,
      dashboardClient: dashboardClient,
    );

    expect(starts, ['mission', 'metrics']);
    expect(missionApi.calls, 1);
    expect(dashboardClient.dashboardCalls, 1);

    mission.complete(_mission('AVAILABLE'));
    await tester.pump();
    expect(find.text('JPA 트랜잭션 경계 읽기'), findsOneWidget);
    expect(find.byKey(const ValueKey('today-metrics-loading')), findsOneWidget);

    dashboardClient.dashboardCompleter.complete({
      'streakDays': 7,
      'progressPercent': 62,
      'nextTaskTitle': 'legacy next task',
      'badges': <String>[],
      'completedContentCount': 12,
    });
  });

  testWidgets('malformed metrics는 안전한 보조 오류로 끝나고 Today primary는 유지한다', (
    tester,
  ) async {
    await _pumpDashboard(
      tester,
      enabled: true,
      missionApi: _DashboardMissionApi([Future.value(_mission('AVAILABLE'))]),
      dashboardClient: _QueuedDashboardClient([
        Future.value({
          'streakDays': 'raw-sensitive-dashboard-payload',
          'progressPercent': 62,
          'nextTaskTitle': 'legacy next task',
          'badges': <String>[],
        }),
      ]),
    );
    await tester.pump();

    expect(find.text('JPA 트랜잭션 경계 읽기'), findsOneWidget);
    expect(find.text('미션 열기'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('dp-next-action-primary')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('today-metrics-error')), findsOneWidget);
    expect(find.textContaining('학습 지표 형식을 확인하지 못했어요.'), findsOneWidget);
    expect(
      find.textContaining('raw-sensitive-dashboard-payload'),
      findsNothing,
    );
  });

  testWidgets('살아 있는 Dashboard에서 owner 전환 시 새 mission을 자동 조회한다', (
    tester,
  ) async {
    final nextOwnerMission = Completer<CurrentMission>();
    final missionApi = _DashboardMissionApi([
      Future.value(_mission('AVAILABLE', availableTitle: '사용자 A 미션')),
      nextOwnerMission.future,
    ]);
    await _pumpDashboard(
      tester,
      enabled: true,
      missionApi: missionApi,
      dashboardClient: _DashboardClient(),
      dynamicOwner: true,
    );
    expect(find.text('사용자 A 미션'), findsOneWidget);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(DashboardPage)),
    );
    container.read(_dashboardOwnerKeyProvider.notifier).changeTo('user-b');
    await tester.pump();

    expect(missionApi.calls, 2);
    expect(find.text('오늘의 미션을 불러오는 중'), findsOneWidget);

    nextOwnerMission.complete(
      _mission('AVAILABLE', availableTitle: '사용자 B 미션'),
    );
    await tester.pump();
    expect(find.text('사용자 B 미션'), findsOneWidget);
    expect(find.text('사용자 A 미션'), findsNothing);
  });

  testWidgets('owner 전환 시 Today mission과 metrics를 함께 비우고 B 데이터만 렌더한다', (
    tester,
  ) async {
    final nextOwnerMission = Completer<CurrentMission>();
    final nextOwnerMetrics = Completer<Map<String, dynamic>>();
    final missionApi = _DashboardMissionApi([
      Future.value(_mission('AVAILABLE', availableTitle: '사용자 A 미션')),
      nextOwnerMission.future,
    ]);
    final dashboardClient = _QueuedDashboardClient([
      Future.value(_dashboardSummary('user-a', 3)),
      nextOwnerMetrics.future,
    ]);
    await _pumpDashboard(
      tester,
      enabled: true,
      missionApi: missionApi,
      dashboardClient: dashboardClient,
      dynamicOwner: true,
    );
    await tester.pumpAndSettle();
    expect(find.text('사용자 A 미션'), findsOneWidget);
    expect(
      tester
          .widgetList<DpKpiCard>(find.byType(DpKpiCard))
          .map((card) => card.value),
      contains(3),
    );

    final container = ProviderScope.containerOf(
      tester.element(find.byType(DashboardPage)),
    );
    container.read(_dashboardOwnerKeyProvider.notifier).changeTo('user-b');
    await tester.pump();

    expect(missionApi.calls, 2);
    expect(dashboardClient.dashboardCalls, 2);
    expect(find.text('사용자 A 미션'), findsNothing);
    expect(find.byType(DpKpiCard), findsNothing);
    expect(find.text('오늘의 미션을 불러오는 중'), findsOneWidget);

    nextOwnerMission.complete(
      _mission('AVAILABLE', availableTitle: '사용자 B 미션'),
    );
    nextOwnerMetrics.complete(_dashboardSummary('user-b', 19));
    await tester.pump();
    await tester.pump();

    expect(find.text('사용자 B 미션'), findsOneWidget);
    expect(
      tester
          .widgetList<DpKpiCard>(find.byType(DpKpiCard))
          .map((card) => card.value),
      contains(19),
    );
    expect(find.text('사용자 A 미션'), findsNothing);
    expect(
      tester
          .widgetList<DpKpiCard>(find.byType(DpKpiCard))
          .map((card) => card.value),
      isNot(contains(3)),
    );
  });

  testWidgets('flag OFF legacy도 owner 전환 시 A 지표를 지우고 B만 렌더한다', (tester) async {
    final nextOwnerMetrics = Completer<Map<String, dynamic>>();
    final dashboardClient = _QueuedDashboardClient([
      Future.value(_dashboardSummary('user-a', 3)),
      nextOwnerMetrics.future,
    ]);
    await _pumpDashboard(
      tester,
      enabled: false,
      missionApi: _DashboardMissionApi([Future.value(_mission('AVAILABLE'))]),
      dashboardClient: dashboardClient,
      dynamicOwner: true,
    );
    await tester.pump();
    expect(find.text('user-a next task'), findsOneWidget);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(DashboardPage)),
    );
    container.read(_dashboardOwnerKeyProvider.notifier).changeTo('user-b');
    await tester.pump();

    expect(dashboardClient.dashboardCalls, 2);
    expect(find.text('user-a next task'), findsNothing);
    expect(find.byKey(const ValueKey('loading')), findsOneWidget);

    nextOwnerMetrics.complete(_dashboardSummary('user-b', 19));
    await tester.pump();
    await tester.pump();
    expect(find.text('user-b next task'), findsOneWidget);
    expect(find.text('user-a next task'), findsNothing);
  });

  testWidgets('계정 전환 뒤 Dashboard 재진입 첫 frame에도 이전 owner 지표를 숨긴다', (
    tester,
  ) async {
    final nextOwnerMetrics = Completer<Map<String, dynamic>>();
    final dashboardClient = _QueuedDashboardClient([
      Future.value(_dashboardSummary('user-a', 3)),
      nextOwnerMetrics.future,
    ]);
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          _config(missionSpineEnabled: false),
        ),
        apiClientProvider.overrideWithValue(dashboardClient),
        currentMissionOwnerKeyProvider.overrideWithValue('user-b'),
        adFetchProvider.overrideWithValue((_) async => null),
      ],
    );
    addTearDown(container.dispose);

    final metrics = container.read(dashboardControllerProvider.notifier);
    metrics.synchronizeOwner('user-a');
    await metrics.load();
    expect(
      (container.read(dashboardControllerProvider) as DashLoaded)
          .summary
          .nextTaskTitle,
      'user-a next task',
    );

    final router = GoRouter(
      routes: [GoRoute(path: '/', builder: (_, _) => const DashboardPage())],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(theme: DpTheme.light(), routerConfig: router),
      ),
    );

    expect(find.text('user-a next task'), findsNothing);
    expect(find.byKey(const ValueKey('loading')), findsOneWidget);
    expect(dashboardClient.dashboardCalls, 2);
  });

  testWidgets('AVAILABLE은 서버 taskId 미션과 하나의 정직한 CTA를 보여준다', (tester) async {
    final missionApi = _DashboardMissionApi([
      Future.value(_mission('AVAILABLE')),
    ]);
    final router = await _pumpDashboard(
      tester,
      enabled: true,
      missionApi: missionApi,
      dashboardClient: _DashboardClient(),
    );

    expect(find.text('4주차 · 미션 1'), findsOneWidget);
    expect(find.text('미션 열기'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('dp-next-action-primary')),
      findsOneWidget,
    );

    await tester.tap(find.text('미션 열기'));
    await tester.pumpAndSettle();
    expect(
      router.routerDelegate.state.uri.toString(),
      '/mission/302/content/77',
    );
    expect(find.text('mission 302 content 77'), findsOneWidget);
    expect(router.canPop(), isTrue);

    router.pop();
    await tester.pumpAndSettle();
    expect(find.byType(DashboardPage), findsOneWidget);
  });

  testWidgets('320px와 200% 텍스트에서도 Today CTA 의미와 한 개의 행동을 유지한다', (tester) async {
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    final semantics = tester.ensureSemantics();

    await _pumpDashboard(
      tester,
      enabled: true,
      missionApi: _DashboardMissionApi([Future.value(_mission('AVAILABLE'))]),
      dashboardClient: _DashboardClient(delayed: true),
    );

    expect(tester.takeException(), isNull);
    expect(
      find.bySemanticsLabel('미션 열기, 예상 결과: 콘텐츠에서 완료 조건을 확인합니다.'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('dp-next-action-primary')),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('NO_ACTIVE_PATH는 지표와 광고를 숨기고 경로 생성 CTA 하나만 보여준다', (tester) async {
    final missionApi = _DashboardMissionApi([
      Future.value(_mission('NO_ACTIVE_PATH')),
    ]);
    await _pumpDashboard(
      tester,
      enabled: true,
      missionApi: missionApi,
      dashboardClient: _DashboardClient(),
    );

    expect(find.text('아직 학습 경로가 없어요'), findsOneWidget);
    expect(find.text('경로 만들기'), findsOneWidget);
    expect(find.byType(DpKpiCard), findsNothing);
    expect(find.byType(AdSlotWidget), findsNothing);
    expect(find.byType(FilledButton), findsOneWidget);
  });

  testWidgets('PATH_COMPLETED는 완료 근거와 경로 CTA 하나를 보여준다', (tester) async {
    final missionApi = _DashboardMissionApi([
      Future.value(_mission('PATH_COMPLETED')),
    ]);
    await _pumpDashboard(
      tester,
      enabled: true,
      missionApi: missionApi,
      dashboardClient: _DashboardClient(),
    );

    expect(find.text('12주 경로를 모두 완료했어요'), findsOneWidget);
    expect(find.text('경로 돌아보기'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('dp-next-action-primary')),
      findsOneWidget,
    );
  });

  testWidgets('MALFORMED_PATH는 추론하지 않고 재조회 CTA 하나를 보여준다', (tester) async {
    final missionApi = _DashboardMissionApi([
      Future.value(_mission('MALFORMED_PATH')),
    ]);
    await _pumpDashboard(
      tester,
      enabled: true,
      missionApi: missionApi,
      dashboardClient: _DashboardClient(),
    );

    expect(find.text('현재 미션을 확인할 수 없어요'), findsOneWidget);
    expect(find.text('다시 시도'), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);
    expect(find.byType(DpKpiCard), findsNothing);
  });

  testWidgets('refresh 실패는 마지막 미션을 stale로 남기고 재조회 행동만 제시한다', (tester) async {
    final failedRefresh = Completer<CurrentMission>();
    final missionApi = _DashboardMissionApi([
      Future.value(_mission('AVAILABLE')),
      failedRefresh.future,
    ]);
    await _pumpDashboard(
      tester,
      enabled: true,
      missionApi: missionApi,
      dashboardClient: _DashboardClient(),
    );

    final scope = ProviderScope.containerOf(
      tester.element(find.byType(DashboardPage)),
    );
    final refresh = scope
        .read(currentMissionControllerProvider.notifier)
        .invalidateAndRefetch();
    failedRefresh.completeError(StateError('network down'));
    await refresh;
    await tester.pump();

    expect(find.text('JPA 트랜잭션 경계 읽기'), findsOneWidget);
    expect(find.text('마지막으로 확인한 미션'), findsOneWidget);
    expect(find.text('미션 다시 확인'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('dp-next-action-primary')),
      findsOneWidget,
    );
  });
}
