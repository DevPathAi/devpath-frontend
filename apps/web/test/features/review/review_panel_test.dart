import 'package:devpath_web/src/features/review/application/review_controller.dart';
import 'package:devpath_web/src/features/review/presentation/review_panel.dart';
import 'package:devpath_web/src/features/review/state/review_state.dart';
import 'package:devpath_web/src/features/dashboard/application/current_mission_controller.dart';
import 'package:devpath_web/src/features/mission/state/mission_workspace_key.dart';
import 'package:devpath_web/src/features/sandbox/application/run_controller.dart';
import 'package:devpath_web/src/features/sandbox/data/sandbox_run_source.dart';
import 'package:devpath_web/src/features/sandbox/state/run_state.dart';
import 'package:devpath_web/src/providers/api_providers.dart';
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart'; // F6-a: 대체행동 라우팅 테스트용

class _FakeReview extends ReviewController {
  _FakeReview(this._initial);
  final ReviewState _initial;
  @override
  ReviewState build() => _initial;
}

final class _RecordingReview extends ReviewController {
  _RecordingReview(super.workspaceKey, this.calls);

  final List<int> calls;

  @override
  ReviewState build() => const ReviewIdle();

  @override
  Future<void> pollForSession(
    int sandboxSessionId, {
    Duration interval = const Duration(seconds: 2),
    int maxAttempts = 30,
  }) async {
    calls.add(sandboxSessionId);
  }
}

final class _TerminalRun extends RunController {
  _TerminalRun(super.workspaceKey);

  @override
  RunState build() => const RunCompleted(
    result: SandboxTerminalResult(
      sessionId: 42,
      status: SandboxSessionStatus.completed,
      exitCode: 0,
      truncated: false,
    ),
    persisted: true,
    explicitRun: true,
  );
}

Widget _host(ProviderContainer c, {MissionWorkspaceKey? workspaceKey}) =>
    UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        theme: DpTheme.light(),
        home: Scaffold(
          body: ReviewPanel(workspaceKey: workspaceKey, onRequest: () {}),
        ),
      ),
    );

// F6-a: context.go('/community')가 동작하도록 GoRouter를 끼운 호스트.
Widget _hostRouter(ProviderContainer c) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(body: ReviewPanel(onRequest: () {})),
      ),
      GoRoute(
        path: '/community',
        builder: (_, _) => const Scaffold(body: Text('COMMUNITY_STUB')),
      ),
    ],
  );
  return UncontrolledProviderScope(
    container: c,
    child: MaterialApp.router(theme: DpTheme.light(), routerConfig: router),
  );
}

void main() {
  testWidgets('idle: 리뷰 요청 버튼', (tester) async {
    final c = ProviderContainer(
      overrides: [
        reviewControllerProvider.overrideWith(
          () => _FakeReview(const ReviewIdle()),
        ),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(_host(c));
    expect(find.text('AI 리뷰 요청'), findsOneWidget);
  });

  testWidgets('loaded: 신뢰도와 개선 라인 표시', (tester) async {
    final c = ProviderContainer(
      overrides: [
        reviewControllerProvider.overrideWith(
          () => _FakeReview(
            const ReviewLoaded(
              CodeReview(
                confidence: 80,
                improvements: [
                  ReviewIssue(message: 'null 체크', line: 3, severity: 'warning'),
                ],
              ),
            ),
          ),
        ),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(_host(c));
    expect(find.textContaining('80'), findsWidgets);
    expect(find.textContaining('null 체크'), findsOneWidget);
  });

  testWidgets('killSwitch: 점검 배너', (tester) async {
    final c = ProviderContainer(
      overrides: [
        reviewControllerProvider.overrideWith(
          () => _FakeReview(const ReviewKillSwitch()),
        ),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(_host(c));
    expect(find.byType(DpKillSwitch), findsOneWidget);
  });

  // F6-a: KILL_SWITCH 대체행동(altActionLabel/onAltAction) 배선 검증.
  testWidgets('killSwitch: 대체행동 버튼 존재 + 탭(라우팅)', (tester) async {
    final c = ProviderContainer(
      overrides: [
        reviewControllerProvider.overrideWith(
          () => _FakeReview(const ReviewKillSwitch()),
        ),
      ],
    );
    addTearDown(c.dispose);
    // context.go가 동작하려면 GoRouter가 필요 — _hostRouter로 '/community' 라우트 제공.
    await tester.pumpWidget(_hostRouter(c));
    await tester.pumpAndSettle();
    expect(find.text('커뮤니티 둘러보기'), findsOneWidget);
    await tester.tap(find.text('커뮤니티 둘러보기'));
    await tester.pumpAndSettle();
    expect(find.text('COMMUNITY_STUB'), findsOneWidget); // 대체행동이 /community로 이동
  });

  // F6-b: Retry-After null/음수 안전 — 0초 오안내 없이 무기한 문구로 분기.
  testWidgets('quota: retryAfter=null이면 무기한 문구(0초 미표시)', (tester) async {
    final c = ProviderContainer(
      overrides: [
        reviewControllerProvider.overrideWith(
          () => _FakeReview(const ReviewQuota(null)),
        ),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(_host(c));
    expect(find.byType(DpQuota), findsOneWidget);
    expect(find.textContaining('0초'), findsNothing); // 0초 오안내 차단
    expect(find.textContaining('잠시 후 다시 시도'), findsOneWidget);
  });

  testWidgets('quota: retryAfter=음수도 무기한 문구로 안전 처리', (tester) async {
    final c = ProviderContainer(
      overrides: [
        reviewControllerProvider.overrideWith(
          () => _FakeReview(const ReviewQuota(-5)),
        ),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(_host(c));
    expect(find.byType(DpQuota), findsOneWidget);
    expect(find.textContaining('-5'), findsNothing);
  });

  // F6-f: 누락 분기 렌더(Loading/Failed) 보강 — 분기 6종 전수 커버.
  testWidgets('loading: 생성 중 표시', (tester) async {
    final c = ProviderContainer(
      overrides: [
        reviewControllerProvider.overrideWith(
          () => _FakeReview(const ReviewLoading()),
        ),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(_host(c));
    expect(find.byType(DpLoading), findsOneWidget);
  });

  testWidgets('failed: 에러 메시지 + 재시도', (tester) async {
    final c = ProviderContainer(
      overrides: [
        reviewControllerProvider.overrideWith(
          () => _FakeReview(const ReviewFailed('서버 오류')),
        ),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(_host(c));
    expect(find.byType(DpError), findsOneWidget);
    expect(find.textContaining('서버 오류'), findsOneWidget);
  });

  testWidgets('refresh/failure 중에도 마지막 valid review를 계속 보여준다', (tester) async {
    const previous = CodeReview(confidence: 86, strengths: ['보존된 장점']);
    final c = ProviderContainer(
      overrides: [
        reviewControllerProvider.overrideWith(
          () => _FakeReview(
            const ReviewLoading(previous: previous, sessionId: 41),
          ),
        ),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(_host(c));

    expect(find.textContaining('86'), findsWidgets);
    expect(find.text('보존된 장점'), findsOneWidget);
    expect(find.textContaining('새 리뷰를 확인'), findsOneWidget);
  });

  // F6-e: RunDone.sandboxSessionId 감지 시 자동 pollForSession 트리거 검증.
  testWidgets('RunDone with sandboxSessionId → auto-poll triggers ReviewLoaded', (
    tester,
  ) async {
    // 목 ApiClient: GET /reviews?sandboxSessionId=42 → DONE
    final client = ApiClient.create(
      const ApiConfig(baseUrl: 'https://t/api/v1'),
    );
    client.dio.httpClientAdapter = MockHttpAdapter({
      'GET /reviews?sandboxSessionId=42': (
        200,
        {
          'status': 'DONE',
          'confidence': 75,
          'strengths': ['자동 폴링 테스트'],
          'improvements': <Map<String, dynamic>>[],
          'security': <Map<String, dynamic>>[],
        },
      ),
    });

    final c = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(client),
        // RunController는 실제 구현 사용(상태 전이 감지용).
        // sandboxRunConnectProvider는 즉시 완료(session=42 포함).
        sandboxRunConnectProvider.overrideWithValue((_, _) async* {
          yield const SseEvent(event: 'log', data: 'ok');
          yield const SseEvent(event: 'session', data: '42');
        }),
      ],
    );
    addTearDown(c.dispose);

    await tester.pumpWidget(_host(c));

    // RunController.run 호출 → RunDone(sandboxSessionId=42) → ReviewPanel이 감지 → pollForSession
    await c.read(runControllerProvider.notifier).run('x', 'PYTHON');

    // pollForSession은 비동기이므로 settle 대기
    await tester.pumpAndSettle();

    expect(find.textContaining('75'), findsWidgets);
    expect(find.textContaining('자동 폴링 테스트'), findsOneWidget);
  });

  testWidgets('canonical RunTerminal은 같은 workspace review만 자동 poll한다', (
    tester,
  ) async {
    const workspaceKey = MissionWorkspaceKey(taskId: 7, contentId: 11);
    final client = ApiClient.create(
      const ApiConfig(baseUrl: 'https://t/api/v1'),
    );
    client.dio.httpClientAdapter = MockHttpAdapter({
      'GET /reviews?sandboxSessionId=42': (
        200,
        {
          'status': 'DONE',
          'confidence': 91,
          'strengths': ['canonical review'],
          'improvements': <Map<String, dynamic>>[],
          'security': <Map<String, dynamic>>[],
        },
      ),
    });
    final c = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(client),
        sandboxRunV2ConnectProvider.overrideWithValue((_) async* {
          yield const SseEvent(event: 'session', data: '42');
          yield const SseEvent(
            event: 'result',
            data:
                '{"sessionId":42,"status":"COMPLETED",'
                '"exitCode":0,"truncated":false}',
          );
        }),
        sandboxSessionReadProvider.overrideWithValue(
          (_) async => SandboxSession(
            sessionId: 42,
            language: SandboxLanguage.python,
            contentId: workspaceKey.contentId,
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
    addTearDown(c.dispose);
    await tester.pumpWidget(_host(c, workspaceKey: workspaceKey));

    await c
        .read(runControllerFamilyProvider(workspaceKey).notifier)
        .run('print("ok")', 'PYTHON');
    await tester.pumpAndSettle();

    expect(find.textContaining('91'), findsWidgets);
    expect(find.text('canonical review'), findsOneWidget);
    expect(c.read(reviewControllerProvider), isA<ReviewIdle>());
  });

  testWidgets('같은 session ID라도 workspace가 바뀌면 새 review를 poll한다', (
    tester,
  ) async {
    const first = MissionWorkspaceKey(taskId: 7, contentId: 11);
    const second = MissionWorkspaceKey(taskId: 8, contentId: 12);
    final firstCalls = <int>[];
    final secondCalls = <int>[];
    final c = ProviderContainer(
      overrides: [
        currentMissionOwnerKeyProvider.overrideWithValue('owner-1'),
        runControllerFamilyProvider(
          first,
        ).overrideWith(() => _TerminalRun(first)),
        runControllerFamilyProvider(
          second,
        ).overrideWith(() => _TerminalRun(second)),
        reviewControllerFamilyProvider(
          first,
        ).overrideWith(() => _RecordingReview(first, firstCalls)),
        reviewControllerFamilyProvider(
          second,
        ).overrideWith(() => _RecordingReview(second, secondCalls)),
      ],
    );
    addTearDown(c.dispose);

    await tester.pumpWidget(_host(c, workspaceKey: first));
    await tester.pump();
    expect(firstCalls, [42]);

    await tester.pumpWidget(_host(c, workspaceKey: second));
    await tester.pump();
    expect(secondCalls, [42]);
  });
}
