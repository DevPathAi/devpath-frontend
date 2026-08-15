import 'dart:convert';
import 'dart:typed_data';

import 'package:devpath_web/src/app/app_config.dart';
import 'package:devpath_web/src/analytics/journey_analytics.dart';
import 'package:devpath_web/src/features/auth/application/auth_controller.dart';
import 'package:devpath_web/src/features/auth/state/auth_state.dart';
import 'package:devpath_web/src/features/dashboard/application/current_mission_controller.dart';
import 'package:devpath_web/src/features/mission/state/mission_workspace_key.dart';
import 'package:devpath_web/src/features/review/application/review_controller.dart';
import 'package:devpath_web/src/features/review/state/review_state.dart';
import 'package:devpath_web/src/features/sandbox/application/run_controller.dart';
import 'package:devpath_web/src/features/sandbox/application/sandbox_funnel_analytics.dart';
import 'package:devpath_web/src/features/sandbox/data/sandbox_funnel_store.dart';
import 'package:devpath_web/src/features/sandbox/data/sandbox_run_source.dart';
import 'package:devpath_web/src/features/sandbox/data/sandbox_session_store.dart';
import 'package:devpath_web/src/features/sandbox/presentation/sandbox_page.dart';
import 'package:devpath_web/src/features/sandbox/state/run_state.dart';
import 'package:devpath_web/src/providers/api_providers.dart';
import 'package:dio/dio.dart';
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const key = MissionWorkspaceKey(taskId: 31, contentId: 3);

final class _ContentAdapter implements HttpClientAdapter {
  _ContentAdapter(this.track, {this.review});
  final String track;
  final Map<String, Object?>? review;
  var contentCalls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future? cancelFuture,
  ) async {
    final isReview = options.path == '/reviews' && review != null;
    if (!isReview) contentCalls += 1;
    return ResponseBody.fromString(
      jsonEncode(
        isReview
            ? review
            : {
                'id': 3,
                'slug': 'content-3',
                'title': '예외 처리 단원',
                'track': track,
                'markdown': '# 예외 처리',
                'conceptTags': <String>[],
                'progress': {
                  'scrollPct': 0.4,
                  'dwellSec': 20,
                  'completed': false,
                  'completedAt': null,
                },
              },
      ),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

final class _AuthedController extends AuthController {
  @override
  AuthState build() => const AuthAuthenticated(
    User(
      id: '73',
      email: 'learner@example.com',
      nickname: '학습자',
      role: UserRole.learner,
      onboardingStatus: OnboardingStatus.done,
      consentStatus: ConsentStatus.done,
    ),
  );
}

class _SpyAnalytics implements JourneyAnalytics {
  final events = <(String, Map<String, Object?>)>[];

  @override
  AnalyticsCaptureStatus capture(
    String event,
    Map<String, Object?> properties,
  ) {
    events.add((event, Map.unmodifiable(properties)));
    return AnalyticsCaptureStatus.accepted;
  }

  @override
  bool identify(String userId) => true;

  @override
  void reset() {}

  @override
  void setOptedOut(bool optedOut) {}
}

final class _ThrowingAnalytics extends _SpyAnalytics {
  @override
  AnalyticsCaptureStatus capture(
    String event,
    Map<String, Object?> properties,
  ) => throw StateError('sdk unavailable');
}

final class _FixedReviewController extends ReviewController {
  _FixedReviewController(this.initial);

  final ReviewState initial;

  @override
  ReviewState build() => initial;

  @override
  Future<void> pollForSession(
    int sandboxSessionId, {
    Duration interval = const Duration(seconds: 2),
    int maxAttempts = 30,
  }) async {}
}

final class _ReadyMissionController extends CurrentMissionController {
  String? _ownerKey;

  @override
  CurrentMissionState build() {
    _ownerKey = ref.read(currentMissionOwnerKeyProvider);
    ref.listen(currentMissionOwnerKeyProvider, (_, nextOwner) {
      if (nextOwner == _ownerKey) return;
      _ownerKey = nextOwner;
      state = const CurrentMissionState(isLoading: true);
    });
    return CurrentMissionState(mission: _mission());
  }

  @override
  Future<CurrentMission?> load({bool force = false}) async => _mission();

  void replace(CurrentMission? mission, {bool isLoading = false}) {
    state = CurrentMissionState(mission: mission, isLoading: isLoading);
  }
}

class _TestOwnerController extends Notifier<String> {
  @override
  String build() => 'user-1';

  void switchTo(String ownerKey) => state = ownerKey;
}

final _testOwnerProvider = NotifierProvider<_TestOwnerController, String>(
  _TestOwnerController.new,
);

final class _SwitchOwnerBeforeChildPostFrame extends ConsumerStatefulWidget {
  const _SwitchOwnerBeforeChildPostFrame();

  @override
  ConsumerState<_SwitchOwnerBeforeChildPostFrame> createState() =>
      _SwitchOwnerBeforeChildPostFrameState();
}

final class _SwitchOwnerBeforeChildPostFrameState
    extends ConsumerState<_SwitchOwnerBeforeChildPostFrame> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(_testOwnerProvider.notifier).switchTo('user-2');
    });
  }

  @override
  Widget build(BuildContext context) => const SandboxPage(workspaceKey: key);
}

final class _RecordingSessionStore implements SandboxSessionStore {
  final reads = <String>[];
  final values = <String, int>{};

  String _entry(String ownerKey, MissionWorkspaceKey workspaceKey) =>
      '$ownerKey:${workspaceKey.taskId}:${workspaceKey.contentId}';

  @override
  int? read(String ownerKey, MissionWorkspaceKey workspaceKey) {
    final entry = _entry(ownerKey, workspaceKey);
    reads.add(entry);
    return values[entry];
  }

  @override
  void write(
    String ownerKey,
    MissionWorkspaceKey workspaceKey,
    int sessionId,
  ) => values[_entry(ownerKey, workspaceKey)] = sessionId;

  @override
  void clear(String ownerKey, MissionWorkspaceKey workspaceKey) {
    values.remove(_entry(ownerKey, workspaceKey));
  }
}

CurrentMission _mission({int contentId = 3}) => CurrentMission.fromJson({
  'outcome': 'AVAILABLE',
  'pathId': 21,
  'weekNum': 2,
  'tasks': [
    {
      'taskId': 31,
      'orderNum': 1,
      'taskType': 'PRACTICE',
      'title': '예외 처리 코드를 실행해 보기',
      'required': true,
      'contentId': contentId,
      'contentSlug': 'content-3',
      'completed': false,
      'completedAt': null,
    },
  ],
  'nextTask': {
    'taskId': 31,
    'orderNum': 1,
    'taskType': 'PRACTICE',
    'title': '예외 처리 코드를 실행해 보기',
    'required': true,
    'contentId': contentId,
    'contentSlug': 'content-3',
    'completed': false,
    'completedAt': null,
  },
  'pathCompleted': false,
});

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required String track,
  SandboxRunV2Connect? connect,
  bool useMock = false,
  SandboxSessionStore? sessionStore,
  SandboxSessionRead? sessionRead,
  JourneyAnalytics? analytics,
  SandboxFunnelStore? funnelStore,
  Map<String, Object?>? review,
  ReviewState? fixedReview,
  bool authenticated = false,
  bool routed = false,
  String? fixedOwner,
}) async {
  final client = ApiClient.create(const ApiConfig(baseUrl: 'https://t/api/v1'))
    ..dio.httpClientAdapter = _ContentAdapter(track, review: review);
  final container = ProviderContainer(
    overrides: [
      appConfigProvider.overrideWithValue(
        AppConfig(
          baseUrl: 'https://t/api/v1',
          useMock: useMock,
          missionSpineEnabled: true,
        ),
      ),
      apiClientProvider.overrideWithValue(client),
      if (fixedOwner != null)
        currentMissionOwnerKeyProvider.overrideWithValue(fixedOwner)
      else
        currentMissionOwnerKeyProvider.overrideWith(
          (ref) => ref.watch(_testOwnerProvider),
        ),
      currentMissionControllerProvider.overrideWith(
        _ReadyMissionController.new,
      ),
      if (authenticated)
        authControllerProvider.overrideWith(_AuthedController.new),
      if (analytics != null)
        journeyAnalyticsProvider.overrideWithValue(analytics),
      if (funnelStore != null)
        sandboxFunnelStoreProvider.overrideWithValue(funnelStore),
      if (fixedReview != null)
        reviewControllerFamilyProvider(
          key,
        ).overrideWith(() => _FixedReviewController(fixedReview)),
      if (connect != null)
        sandboxRunV2ConnectProvider.overrideWithValue(connect),
      sandboxSessionStoreProvider.overrideWithValue(
        sessionStore ?? MemorySandboxSessionStore(),
      ),
      if (sessionRead != null)
        sandboxSessionReadProvider.overrideWithValue(sessionRead)
      else if (connect != null)
        sandboxSessionReadProvider.overrideWithValue(
          (_) async => SandboxSession(
            sessionId: 91,
            language: SandboxLanguage.java,
            contentId: 3,
            codeBlockId: null,
            stdout: 'ok\n',
            stderr: '',
            exitCode: 0,
            status: SandboxSessionStatus.completed,
            truncated: false,
            startedAt: DateTime.utc(2026, 8, 16),
            finishedAt: DateTime.utc(2026, 8, 16, 0, 0, 1),
          ),
        ),
    ],
  );
  addTearDown(container.dispose);
  final page = const SandboxPage(workspaceKey: key);
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, _) => page),
      GoRoute(
        path: '/path/:pathId/today',
        builder: (_, state) => Text(
          'TODAY:${state.pathParameters['pathId']}',
          textDirection: TextDirection.ltr,
        ),
      ),
    ],
  );
  if (routed) addTearDown(router.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: routed
          ? MaterialApp.router(theme: DpTheme.light(), routerConfig: router)
          : MaterialApp(theme: DpTheme.light(), home: page),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump();
  return container;
}

void main() {
  testWidgets(
    'canonical hierarchy는 Mission Header→Context Capsule→단일 Next Action이다',
    (tester) async {
      SandboxRunRequest? captured;
      await _pump(
        tester,
        track: 'BACKEND_SPRING',
        connect: (request) async* {
          captured = request;
          yield const SseEvent(event: 'session', data: '91');
          yield const SseEvent(
            event: 'result',
            data:
                '{"sessionId":91,"status":"COMPLETED",'
                '"exitCode":0,"truncated":false}',
          );
        },
      );

      expect(find.byType(DpMissionHeader), findsOneWidget);
      expect(find.text('예외 처리 코드를 실행해 보기'), findsWidgets);
      expect(find.byType(DpContextCapsule), findsOneWidget);
      expect(find.byType(DpNextActionBand), findsOneWidget);
      expect(find.text('코드 실행'), findsOneWidget);
      expect(find.textContaining('JAVA 일반 템플릿'), findsOneWidget);
      expect(find.textContaining('백엔드 (Spring)'), findsOneWidget);
      expect(find.textContaining('BACKEND_SPRING'), findsNothing);
      expect(find.textContaining('contentId'), findsNothing);
      expect(find.textContaining('public class Main'), findsOneWidget);
      expect(find.textContaining('void main()'), findsNothing);

      await tester.ensureVisible(find.byType(DpNextActionBand));
      await tester.tap(find.text('코드 실행'));
      await tester.pumpAndSettle();
      expect(captured?.contentId, 3);
      expect(captured?.codeBlockId, isNull);
      expect(captured?.language, SandboxLanguage.java);
    },
  );

  testWidgets('MOBILE_FLUTTER는 지원하지 않는 runtime을 Java로 실행하지 않는다', (
    tester,
  ) async {
    var calls = 0;
    await _pump(
      tester,
      track: 'MOBILE_FLUTTER',
      connect: (_) {
        calls += 1;
        return const Stream.empty();
      },
    );

    expect(
      find.textContaining('Flutter/Dart runtime을 지원하지 않습니다'),
      findsOneWidget,
    );
    expect(find.textContaining('public class Main'), findsNothing);
    expect(find.text('코드 실행'), findsOneWidget);
    final band = tester.widget<DpNextActionBand>(find.byType(DpNextActionBand));
    expect(band.state, DpNextActionState.disabled);
    expect(calls, 0);
  });

  testWidgets('FULLSTACK은 runtime 선택 전 비활성이고 명시 선택 뒤 generic을 실행한다', (
    tester,
  ) async {
    SandboxRunRequest? captured;
    await _pump(
      tester,
      track: 'FULLSTACK',
      connect: (request) async* {
        captured = request;
        yield const SseEvent(event: 'session', data: '91');
        yield const SseEvent(
          event: 'result',
          data:
              '{"sessionId":91,"status":"COMPLETED",'
              '"exitCode":0,"truncated":false}',
        );
      },
    );

    expect(find.textContaining('실행 언어를 확정할 수 없습니다'), findsOneWidget);
    var band = tester.widget<DpNextActionBand>(find.byType(DpNextActionBand));
    expect(band.state, DpNextActionState.disabled);

    await tester.ensureVisible(
      find.byKey(const Key('sandbox_language_dropdown')),
    );
    await tester.tap(find.byKey(const Key('sandbox_language_dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('NODE').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('console.log'), findsOneWidget);
    expect(find.text('NODE 일반 템플릿'), findsOneWidget);
    expect(find.text('runtime 선택 후 일반 템플릿'), findsNothing);
    band = tester.widget<DpNextActionBand>(find.byType(DpNextActionBand));
    expect(band.state, DpNextActionState.ready);

    await tester.tap(find.text('코드 실행'));
    await tester.pumpAndSettle();
    expect(captured?.language, SandboxLanguage.node);
  });

  testWidgets('320px·200%에서도 가로 overflow와 primary 중복이 없다', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await _pump(tester, track: 'PYTHON_BACKEND');
    expect(tester.takeException(), isNull);
    expect(find.byType(DpNextActionBand), findsOneWidget);
    expect(find.text('코드 실행'), findsOneWidget);
  });

  testWidgets('ON+mock canonical 실행은 terminal owner GET까지 완주한다', (
    tester,
  ) async {
    final container = await _pump(
      tester,
      track: 'BACKEND_SPRING',
      useMock: true,
    );

    await tester.ensureVisible(find.byType(DpNextActionBand));
    await tester.tap(find.text('코드 실행'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    await tester.pumpAndSettle();

    final state = container.read(runControllerFamilyProvider(key));
    expect(state, isA<RunCompleted>());
    expect(state.sandboxSessionId, 1);
    expect(state.logs, contains('완료 (0.8s)'));
    final persisted = await container.read(sandboxSessionReadProvider)(1);
    expect(persisted.contentId, key.contentId);
    expect(persisted.language, SandboxLanguage.java);
    expect(persisted.stdout, contains('완료 (0.8s)'));
    expect(find.text('리뷰 확인'), findsOneWidget);
  });

  testWidgets('Today의 task/content pair가 사라지면 실행을 fail-closed한다', (
    tester,
  ) async {
    var calls = 0;
    final container = await _pump(
      tester,
      track: 'BACKEND_SPRING',
      connect: (_) {
        calls += 1;
        return const Stream.empty();
      },
    );
    expect(find.byType(DpNextActionBand), findsOneWidget);

    final mission =
        container.read(currentMissionControllerProvider.notifier)
            as _ReadyMissionController;
    mission.replace(_mission(contentId: 4));
    await tester.pump();

    expect(find.byType(DpNextActionBand), findsNothing);
    expect(find.textContaining('현재 미션과 실습 연결'), findsOneWidget);
    expect(calls, 0);
  });

  testWidgets('mounted canonical 화면에서 owner가 바뀌면 즉시 실행을 닫는다', (tester) async {
    final container = await _pump(tester, track: 'BACKEND_SPRING');
    expect(find.byType(DpNextActionBand), findsOneWidget);

    container.read(_testOwnerProvider.notifier).switchTo('user-2');
    await tester.pump();

    expect(find.byType(DpNextActionBand), findsNothing);
    expect(find.textContaining('현재 미션을 다시 확인'), findsOneWidget);
    expect(container.read(runControllerFamilyProvider(key)), isA<RunIdle>());
  });

  testWidgets('예약된 canonical load는 owner가 바뀌면 새 계정에서 실행되지 않는다', (tester) async {
    final adapter = _ContentAdapter('BACKEND_SPRING');
    final client = ApiClient.create(
      const ApiConfig(baseUrl: 'https://t/api/v1'),
    )..dio.httpClientAdapter = adapter;
    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(client),
        currentMissionOwnerKeyProvider.overrideWith(
          (ref) => ref.watch(_testOwnerProvider),
        ),
        currentMissionControllerProvider.overrideWith(
          _ReadyMissionController.new,
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: DpTheme.light(),
          home: const _SwitchOwnerBeforeChildPostFrame(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();

    expect(container.read(_testOwnerProvider), 'user-2');
    expect(adapter.contentCalls, 0);
    expect(find.textContaining('현재 미션을 다시 확인'), findsOneWidget);
  });

  testWidgets('A→B same route에서 B의 저장 session을 다시 restore한다', (tester) async {
    final store = _RecordingSessionStore()
      ..values['user-2:${key.taskId}:${key.contentId}'] = 91;
    var sessionReads = 0;
    final container = await _pump(
      tester,
      track: 'BACKEND_SPRING',
      sessionStore: store,
      connect: (_) => const Stream.empty(),
      sessionRead: (_) async {
        sessionReads += 1;
        return SandboxSession(
          sessionId: 91,
          language: SandboxLanguage.java,
          contentId: key.contentId,
          codeBlockId: null,
          stdout: 'restored\n',
          stderr: '',
          exitCode: 0,
          status: SandboxSessionStatus.completed,
          truncated: false,
          startedAt: DateTime.utc(2026, 8, 16),
          finishedAt: DateTime.utc(2026, 8, 16, 0, 0, 1),
        );
      },
    );
    expect(store.reads, contains('user-1:${key.taskId}:${key.contentId}'));

    container.read(_testOwnerProvider.notifier).switchTo('user-2');
    await tester.pump();
    final mission =
        container.read(currentMissionControllerProvider.notifier)
            as _ReadyMissionController;
    mission.replace(_mission());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump();
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1)),
    );
    await tester.pump();

    expect(store.reads, contains('user-2:${key.taskId}:${key.contentId}'));
    expect(sessionReads, 1);
    expect(
      container.read(runControllerFamilyProvider(key)),
      isA<RunCompleted>(),
    );
  });

  testWidgets(
    'persisted success와 valid ReviewLoaded는 exact funnel을 한 번 보내고 다음 Today로 간다',
    (tester) async {
      final semantics = tester.ensureSemantics();
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final analytics = _SpyAnalytics();
      final store = MemorySandboxFunnelStore();
      final container = await _pump(
        tester,
        track: 'BACKEND_SPRING',
        authenticated: true,
        fixedOwner: '73',
        routed: true,
        analytics: analytics,
        funnelStore: store,
        review: const {
          'id': '501',
          'status': 'DONE',
          'confidence': 92,
          'strengths': ['정확한 예외 처리'],
          'improvements': <Map<String, Object?>>[],
          'security': <Map<String, Object?>>[],
        },
        connect: (_) async* {
          yield const SseEvent(event: 'session', data: '91');
          yield const SseEvent(
            event: 'result',
            data:
                '{"sessionId":91,"status":"COMPLETED",'
                '"exitCode":0,"truncated":false}',
          );
        },
      );

      await tester.ensureVisible(find.text('코드 실행'));
      await tester.tap(find.text('코드 실행'));
      await tester.pumpAndSettle();

      final practice = analytics.events.singleWhere(
        (entry) => entry.$1 == 'first_practice_succeeded',
      );
      expect(practice.$2, {
        'user_id': '73',
        'path_id': 21,
        'task_id': 31,
        'content_id': 3,
        'run_id': 91,
        'first_successful_run': true,
      });
      final review = analytics.events.singleWhere(
        (entry) => entry.$1 == 'contextual_review_viewed',
      );
      expect(review.$2, {
        'user_id': '73',
        'task_id': 31,
        'review_id': 501,
        'approved_context_field_count': 1,
        'next_action_outcome': 'next_mission',
        'first_view': true,
      });
      for (final event in analytics.events) {
        expect(event.$2.keys, isNot(containsAll(['code', 'output', 'status'])));
      }

      expect(
        find.byType(DpNextActionBand, skipOffstage: false),
        findsOneWidget,
      );
      expect(find.text('리뷰 확인', skipOffstage: false), findsNothing);
      expect(find.text('다음 미션으로', skipOffstage: false), findsOneWidget);
      expect(tester.takeException(), isNull);

      final router = GoRouter.of(tester.element(find.byType(SandboxPage)));
      await tester.tap(find.text('리뷰').first);
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView).last, const Offset(0, -320));
      await tester.pumpAndSettle();
      expect(
        tester
            .getSemantics(find.byKey(const ValueKey('dp-next-action-primary')))
            .label,
        contains('다음 미션으로'),
      );
      expect(find.textContaining('조정'), findsNothing);
      await tester.tap(find.text('다음 미션으로'));
      await tester.pumpAndSettle();
      expect(find.text('TODAY:21'), findsOneWidget);

      router.go('/');
      await tester.pumpAndSettle();
      expect(
        container.read(runControllerFamilyProvider(key)),
        isA<RunCompleted>(),
      );
      expect(
        analytics.events.where(
          (event) => event.$1 == 'first_practice_succeeded',
        ),
        hasLength(1),
      );
      expect(
        analytics.events.where(
          (event) => event.$1 == 'contextual_review_viewed',
        ),
        hasLength(1),
      );
      semantics.dispose();
    },
  );

  testWidgets('invalid review id는 review funnel을 보내지 않는다', (tester) async {
    final analytics = _SpyAnalytics();
    await _pump(
      tester,
      track: 'BACKEND_SPRING',
      authenticated: true,
      fixedOwner: '73',
      analytics: analytics,
      funnelStore: MemorySandboxFunnelStore(),
      review: const {
        'id': 'not-a-db-id',
        'status': 'DONE',
        'confidence': 80,
        'strengths': <String>[],
        'improvements': <Map<String, Object?>>[],
        'security': <Map<String, Object?>>[],
      },
      connect: (_) async* {
        yield const SseEvent(event: 'session', data: '91');
        yield const SseEvent(
          event: 'result',
          data:
              '{"sessionId":91,"status":"COMPLETED",'
              '"exitCode":0,"truncated":false}',
        );
      },
    );

    await tester.ensureVisible(find.text('코드 실행'));
    await tester.tap(find.text('코드 실행'));
    await tester.pumpAndSettle();

    expect(
      analytics.events.where((event) => event.$1 == 'contextual_review_viewed'),
      isEmpty,
    );
  });

  testWidgets('mismatched/partial Review state와 legacy 화면은 funnel 0건이다', (
    tester,
  ) async {
    final analytics = _SpyAnalytics();
    await _pump(
      tester,
      track: 'BACKEND_SPRING',
      authenticated: true,
      fixedOwner: '73',
      analytics: analytics,
      funnelStore: MemorySandboxFunnelStore(),
      fixedReview: const ReviewLoading(
        previous: CodeReview(id: '501', status: 'DONE', confidence: 80),
        sessionId: 92,
      ),
    );
    await tester.pump();
    expect(analytics.events, isEmpty);

    final legacyContainer = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(_AuthedController.new),
        journeyAnalyticsProvider.overrideWithValue(analytics),
        sandboxFunnelStoreProvider.overrideWithValue(
          MemorySandboxFunnelStore(),
        ),
      ],
    );
    addTearDown(legacyContainer.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: legacyContainer,
        child: MaterialApp(theme: DpTheme.light(), home: const SandboxPage()),
      ),
    );
    await tester.pump();
    expect(analytics.events, isEmpty);
  });

  testWidgets('analytics SDK throw도 persisted run UI를 막지 않는다', (tester) async {
    final container = await _pump(
      tester,
      track: 'BACKEND_SPRING',
      authenticated: true,
      fixedOwner: '73',
      analytics: _ThrowingAnalytics(),
      funnelStore: MemorySandboxFunnelStore(),
      connect: (_) async* {
        yield const SseEvent(event: 'session', data: '91');
        yield const SseEvent(
          event: 'result',
          data:
              '{"sessionId":91,"status":"COMPLETED",'
              '"exitCode":0,"truncated":false}',
        );
      },
    );

    await tester.ensureVisible(find.text('코드 실행'));
    await tester.tap(find.text('코드 실행'));
    await tester.pumpAndSettle();

    expect(
      container.read(runControllerFamilyProvider(key)),
      isA<RunCompleted>(),
    );
    expect(tester.takeException(), isNull);
  });
}
