import 'dart:async';
import 'dart:convert';

import 'package:devpath_web/src/analytics/journey_analytics.dart';
import 'package:devpath_web/src/analytics/path_analytics.dart';
import 'package:devpath_web/src/app/app_config.dart';
import 'package:devpath_web/src/data/web_mock_fixtures.dart';
import 'package:devpath_web/src/features/auth/application/auth_controller.dart';
import 'package:devpath_web/src/features/auth/state/auth_state.dart';
import 'package:devpath_web/src/features/path/application/path_controller.dart';
import 'package:devpath_web/src/features/path/data/path_sse_source.dart';
import 'package:devpath_web/src/providers/api_providers.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// appConfigProvider 오버라이드용 최소 헬퍼(P4a에 전용 헬퍼가 없어 여기서 정의).
AppConfig testAppConfig({Duration? sseTimeout}) => AppConfig(
  baseUrl: 'https://test/api/v1',
  useMock: true,
  sseTimeout: sseTimeout ?? const Duration(seconds: 60),
);

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
  throw Exception('연결 끊김');
}

class _MalformedPathClient implements ApiClient {
  @override
  Future<T> get<T>(String path, {Map<String, dynamic>? query}) async =>
      <String, dynamic>{'pathId': 'not-an-int'} as T;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _DelayedPathClient implements ApiClient {
  final requests = <Completer<Map<String, dynamic>>>[];

  @override
  Future<T> get<T>(String path, {Map<String, dynamic>? query}) {
    final request = Completer<Map<String, dynamic>>();
    requests.add(request);
    return request.future.then((value) => value as T);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _StubLearningPathApi extends LearningPathApi {
  _StubLearningPathApi({this.path, this.error}) : super(_MalformedPathClient());

  final LearningPath? path;
  final Object? error;
  var currentPathCalls = 0;

  @override
  Future<LearningPath> currentPath() async {
    currentPathCalls += 1;
    if (currentPathCalls == 1) {
      final failure = error;
      if (failure != null) throw failure;
    }
    return path!;
  }
}

class _AuthedAuthController extends AuthController {
  @override
  AuthState build() => const AuthAuthenticated(
    User(
      id: '73',
      email: 'release@staging.invalid',
      nickname: 'Release',
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
    events.add((event, properties));
    return AnalyticsCaptureStatus.accepted;
  }

  @override
  bool identify(String userId) => true;

  @override
  void reset() {}

  @override
  void setOptedOut(bool optedOut) {}
}

Future<void> _flushUntil(bool Function() condition) async {
  for (var i = 0; i < 20 && !condition(); i++) {
    await Future<void>.delayed(Duration.zero);
  }
  expect(condition(), isTrue);
}

void main() {
  test('경로 조회는 공용 LearningPathApi.currentPath 계약을 사용한다', () async {
    final learningPathApi = _StubLearningPathApi(
      path: LearningPath.fromJson({...mockLearningPath(), 'pathId': 707}),
    );
    final container = ProviderContainer(
      overrides: [
        learningPathApiProvider.overrideWithValue(learningPathApi),
        apiClientProvider.overrideWithValue(_MalformedPathClient()),
        pathSseConnectProvider.overrideWithValue(
          () => throw StateError('existing path should not regenerate'),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(pathControllerProvider.notifier).loadOrStart();

    expect(learningPathApi.currentPathCalls, 1);
    expect(container.read(pathControllerProvider).result?.pathId, 707);
  });

  test('기존 진단 handoff는 continuation과 첫 path view를 순서대로 기록한다', () async {
    final analytics = _SpyAnalytics();
    final handoff = PathAnalyticsHandoffStore()
      ..stage(
        const PathAnalyticsHandoff(
          branch: PathAnalyticsBranch.existing,
          userId: '73',
          assessmentId: 77,
          guestId: '123e4567-e89b-42d3-a456-426614174000',
        ),
      );
    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(_AuthedAuthController.new),
        journeyAnalyticsProvider.overrideWithValue(analytics),
        pathAnalyticsHandoffStoreProvider.overrideWithValue(handoff),
        analyticsSessionIdProvider.overrideWithValue('A' * 22),
        learningPathApiProvider.overrideWithValue(
          _StubLearningPathApi(
            path: LearningPath.fromJson({...mockLearningPath(), 'pathId': 707}),
          ),
        ),
        pathSseConnectProvider.overrideWithValue(
          () => throw StateError('existing path should not regenerate'),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(pathControllerProvider.notifier).loadOrStart();
    container
        .read(pathControllerProvider.notifier)
        .captureViewedPath(
          container.read(pathControllerProvider).result!,
          userId: '73',
        );

    expect(analytics.events.map((event) => event.$1), [
      'existing_path_continued',
      'path_first_viewed',
    ]);
    expect(analytics.events[0].$2, {
      'user_id': '73',
      'path_id': 707,
      'assessment_id': 77,
    });
    expect(analytics.events[1].$2, {
      'user_id': '73',
      'path_id': 707,
      'originating_session_id': 'A' * 22,
    });
  });

  test('새 경로 생성 handoff는 generated 뒤 첫 path view를 기록한다', () async {
    final analytics = _SpyAnalytics();
    final handoff = PathAnalyticsHandoffStore()
      ..stage(
        const PathAnalyticsHandoff(
          branch: PathAnalyticsBranch.generated,
          userId: '73',
          assessmentId: 77,
        ),
      );
    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(_AuthedAuthController.new),
        journeyAnalyticsProvider.overrideWithValue(analytics),
        pathAnalyticsHandoffStoreProvider.overrideWithValue(handoff),
        analyticsSessionIdProvider.overrideWithValue('B' * 22),
        learningPathApiProvider.overrideWithValue(
          _StubLearningPathApi(
            path: LearningPath.fromJson({...mockLearningPath(), 'pathId': 808}),
          ),
        ),
        pathSseConnectProvider.overrideWithValue(() => _emit(const ['done'])),
      ],
    );
    addTearDown(container.dispose);

    await container.read(pathControllerProvider.notifier).start();
    container
        .read(pathControllerProvider.notifier)
        .captureViewedPath(
          container.read(pathControllerProvider).result!,
          userId: '73',
        );

    expect(analytics.events.map((event) => event.$1), [
      'path_generated',
      'path_first_viewed',
    ]);
    expect(analytics.events[0].$2, {
      'path_id': 808,
      'assessment_id': 77,
      'user_id': '73',
    });
    expect(analytics.events[1].$2, {
      'user_id': '73',
      'path_id': 808,
      'originating_session_id': 'B' * 22,
    });
  });

  test('공용 currentPath의 404도 기존처럼 생성 SSE로 이어진다', () async {
    final learningPathApi = _StubLearningPathApi(
      path: LearningPath.fromJson(mockLearningPath()),
      error: const ApiException(
        code: ApiErrorCode.unknown,
        message: '경로 없음',
        status: 404,
      ),
    );
    final container = ProviderContainer(
      overrides: [
        learningPathApiProvider.overrideWithValue(learningPathApi),
        pathSseConnectProvider.overrideWithValue(() => _emit(kPathStages)),
      ],
    );
    addTearDown(container.dispose);

    await container.read(pathControllerProvider.notifier).loadOrStart();

    expect(learningPathApi.currentPathCalls, 2);
    expect(container.read(pathControllerProvider).phase, PathPhase.complete);
  });

  test('reset 중인 GET의 늦은 응답은 idle state를 덮지 않는다', () async {
    final api = _DelayedPathClient();
    final container = ProviderContainer(
      overrides: [apiClientProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);
    final controller = container.read(pathControllerProvider.notifier);

    final load = controller.loadOrStart();
    await _flushUntil(() => api.requests.length == 1);
    controller.reset();
    api.requests.single.complete(mockLearningPath());

    await load.timeout(const Duration(seconds: 1));
    expect(container.read(pathControllerProvider).phase, PathPhase.idle);
  });

  test('A reset 뒤 B load보다 늦게 끝난 A GET은 B 경로를 덮지 않는다', () async {
    final api = _DelayedPathClient();
    final container = ProviderContainer(
      overrides: [apiClientProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);
    final controller = container.read(pathControllerProvider.notifier);

    final loadA = controller.loadOrStart();
    await _flushUntil(() => api.requests.length == 1);
    controller.reset();
    final loadB = controller.loadOrStart();
    await _flushUntil(() => api.requests.length == 2);

    api.requests[1].complete({...mockLearningPath(), 'pathId': 202});
    await loadB.timeout(const Duration(seconds: 1));
    expect(container.read(pathControllerProvider).result?.pathId, 202);

    api.requests[0].complete({...mockLearningPath(), 'pathId': 101});
    await loadA.timeout(const Duration(seconds: 1));
    expect(container.read(pathControllerProvider).result?.pathId, 202);
  });

  test('reset은 이벤트 없는 SSE start Future도 즉시 완료한다', () async {
    final events = StreamController<SseEvent>();
    final container = ProviderContainer(
      overrides: [
        pathSseConnectProvider.overrideWithValue(() => events.stream),
      ],
    );
    addTearDown(() async {
      await events.close();
      container.dispose();
    });
    final controller = container.read(pathControllerProvider.notifier);

    final start = controller.start();
    await Future<void>.delayed(Duration.zero);
    controller.reset();

    await start.timeout(const Duration(seconds: 1));
    expect(container.read(pathControllerProvider).phase, PathPhase.idle);
  });

  test('reset 뒤 SSE done의 늦은 GET은 idle state를 덮지 않는다', () async {
    final api = _DelayedPathClient();
    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(api),
        pathSseConnectProvider.overrideWithValue(() => _emit(const ['done'])),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(pathControllerProvider.notifier);

    final start = controller.start();
    await _flushUntil(() => api.requests.length == 1);
    controller.reset();
    api.requests.single.complete(mockLearningPath());

    await start.timeout(const Duration(seconds: 1));
    expect(container.read(pathControllerProvider).phase, PathPhase.idle);
  });

  test('정상: 4단계 후 완료(타임라인 결과 로드)', () async {
    final container = ProviderContainer(
      overrides: [
        pathSseConnectProvider.overrideWithValue(() => _emit(kPathStages)),
      ],
    );
    addTearDown(container.dispose);

    await container.read(pathControllerProvider.notifier).start();

    final s = container.read(pathControllerProvider);
    expect(s.phase, PathPhase.complete);
    expect(s.completed, kPathStageLabels); // 3단계 모두
    expect(s.result, isNotNull);
    expect(s.result!.milestones, hasLength(12));
    expect(s.result!.milestones.first.tasks, hasLength(3));
  });

  test('기존 경로가 있으면 생성 SSE를 시작하지 않고 바로 로드한다', () async {
    final container = ProviderContainer(
      overrides: [
        pathSseConnectProvider.overrideWithValue(
          () => throw StateError('existing path should not regenerate'),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(pathControllerProvider.notifier).loadOrStart();

    final s = container.read(pathControllerProvider);
    expect(s.phase, PathPhase.complete);
    expect(s.completed, kPathStageLabels);
    expect(s.result, isNotNull);
  });

  test('초기 경로 응답이 잘못되면 정제된 failed 상태로 종료한다', () async {
    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(_MalformedPathClient()),
        pathSseConnectProvider.overrideWithValue(
          () => throw StateError('malformed path must not start SSE'),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(pathControllerProvider.notifier).loadOrStart();

    final s = container.read(pathControllerProvider);
    expect(s.phase, PathPhase.failed);
    expect(s.result, isNull);
    expect(s.error, '학습 경로를 불러오지 못했어요. 다시 시도해 주세요.');
  });

  test('SSE done 뒤 경로 응답이 잘못되면 정제된 failed로 종료한다', () async {
    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(_MalformedPathClient()),
        pathSseConnectProvider.overrideWithValue(() => _emit(const ['done'])),
      ],
    );
    addTearDown(container.dispose);

    await container.read(pathControllerProvider.notifier).start();

    final s = container.read(pathControllerProvider);
    expect(s.phase, PathPhase.failed);
    expect(s.result, isNull);
    expect(s.error, '학습 경로를 불러오지 못했어요. 다시 시도해 주세요.');
  });

  test('중단 시 완료 단계 보존 후 다시 생성으로 처음부터 완성', () async {
    var calls = 0;
    final container = ProviderContainer(
      overrides: [
        pathSseConnectProvider.overrideWithValue(() {
          calls++;
          return calls == 1
              ? _emitThenError(['collecting', 'generating'])
              : _emit(kPathStages);
        }),
      ],
    );
    addTearDown(container.dispose);

    final ctrl = container.read(pathControllerProvider.notifier);
    await ctrl.start();

    var s = container.read(pathControllerProvider);
    expect(s.phase, PathPhase.partial); // 중단
    expect(s.completed, ['진단 분석', '경로 생성']); // 완료 단계 보존
    expect(s.result, isNull);

    await ctrl.start(); // 처음부터 다시 생성

    s = container.read(pathControllerProvider);
    expect(calls, 2);
    expect(s.phase, PathPhase.complete);
    expect(s.completed, kPathStageLabels);
    expect(s.result, isNotNull);
  });

  test(
    'F4: 중간 503(KILL_SWITCH)은 partial이 아니라 killSwitch로 종료(이어하기 루프 차단)',
    () async {
      final container = ProviderContainer(
        overrides: [
          pathSseConnectProvider.overrideWithValue(() async* {
            yield SseEvent(
              event: 'progress',
              data: jsonEncode({
                'stage': 'collecting',
                'progress': 0.15,
                'message': 'collecting',
              }),
            );
            throw const ApiException(
              code: ApiErrorCode.aiKillSwitchActive,
              message: 'AI 처리 일시 중단',
            );
          }),
        ],
      );
      addTearDown(container.dispose);

      await container.read(pathControllerProvider.notifier).start();

      final s = container.read(pathControllerProvider);
      expect(s.phase, PathPhase.killSwitch); // partial 아님
      expect(s.completed, ['진단 분석']); // 503 직전까지는 보존
    },
  );

  test('D2: 60s 무이벤트 → partial 전환', () async {
    // sseTimeout을 짧게 오버라이드하고, 첫 단계 후 더는 이벤트가 없는(열린) 스트림 주입.
    // async*+무한 await는 구독 취소가 hang하므로, 취소 가능한 StreamController로 무이벤트를 재현.
    final hang = StreamController<SseEvent>();
    hang.add(
      SseEvent(
        event: 'progress',
        data: jsonEncode({
          'stage': 'collecting',
          'progress': 0.15,
          'message': 'collecting',
        }),
      ),
    );
    addTearDown(hang.close);
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWith(
          (ref) => testAppConfig(sseTimeout: const Duration(milliseconds: 50)),
        ),
        pathSseConnectProvider.overrideWithValue(() => hang.stream),
      ],
    );
    addTearDown(container.dispose);

    await container.read(pathControllerProvider.notifier).start();

    final s = container.read(pathControllerProvider);
    expect(s.phase, PathPhase.partial); // 타임아웃 → 다시 생성 가능
    expect(s.completed, ['진단 분석']); // 무이벤트 직전 단계 보존
  });

  // 인밴드 progress(stage=error)는 C2에서 폐지 — 백엔드는 event:error 프레임을 보내고
  // SseClient가 ApiException으로 throw한다. 아래 "중간 ApiException" 테스트가 대체한다.

  test('중간 ApiException(event:error 유래)은 failed로 표면화한다', () async {
    Stream<SseEvent> emitThenApi() async* {
      yield SseEvent(
        event: 'progress',
        data: jsonEncode({
          'stage': 'collecting',
          'progress': 0.15,
          'message': 'x',
          'pathId': null,
        }),
      );
      throw const ApiException(
        code: ApiErrorCode.unknown,
        message: 'ai-svc path generate failed',
      );
    }

    final container = ProviderContainer(
      overrides: [
        pathSseConnectProvider.overrideWithValue(() => emitThenApi()),
      ],
    );
    addTearDown(container.dispose);
    await container.read(pathControllerProvider.notifier).start();
    final st = container.read(pathControllerProvider);
    expect(st.phase, PathPhase.failed);
    expect(st.error, 'ai-svc path generate failed');
  });
}
