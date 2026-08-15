import 'package:devpath_web/src/app/app.dart';
import 'package:devpath_web/src/app/app_config.dart';
import 'package:devpath_web/src/data/web_mock_fixtures.dart';
import 'package:devpath_web/src/features/auth/application/auth_controller.dart';
import 'package:devpath_web/src/features/auth/state/auth_state.dart';
import 'package:devpath_web/src/features/diagnostic/application/diagnostic_controller.dart';
import 'package:devpath_web/src/features/diagnostic/presentation/diagnostic_page.dart';
import 'package:devpath_web/src/features/path/data/path_sse_source.dart';
import 'package:devpath_web/src/features/path/presentation/path_page.dart';
import 'package:devpath_web/src/providers/api_providers.dart';
import 'package:dio/dio.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 테스트 전용 AuthController: build()가 AuthUnauthenticated를 즉시 반환해
/// bootstrapSession microtask 없이 로그인 화면에서 시작한다.
/// bootstrapFromCallback()은 목 모드 LoginPage가 호출하므로 super에 위임한다.
class _NoBootstrapAuthController extends AuthController {
  @override
  AuthState build() => const AuthUnauthenticated();
}

/// 즉시 완료되는 진단 API: next()가 null을 반환해 바로 complete()로 진행.
class _FastCompleteAssessmentApi implements AssessmentApi {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);

  @override
  Future<int> startMember(String track) async => 1;

  @override
  Future<NextQuestion?> next({int? assessmentId, String? guestId}) async =>
      null;

  @override
  Future<AssessmentResult> complete({
    int? assessmentId,
    String? guestId,
  }) async =>
      const AssessmentResult(diagnosedLevel: 'MID', confidenceWeight: 0.8);
}

const _missionSpineOn = AppConfig(
  baseUrl: 'https://mock.devpath.ai',
  useMock: true,
  missionSpineEnabled: true,
);

/// 목 모드 ApiClient(web 픽스처). 페이크의 위임 대상(api_providers와 동일 구성).
ApiClient _mockInner() {
  final inner = ApiClient.create(const ApiConfig(baseUrl: '', useMock: true));
  inner.dio.httpClientAdapter = MockHttpAdapter(webMockFixtures);
  return inner;
}

/// D2 신규 사용자: diagnostic saved-preview의 typed branch probe와 Path의
/// loadOrStart가 각각 404를 받아야 한다. 이후 생성 결과 조회는 목 inner(200)에
/// 위임한다. 나머지(post/sse/dio)는 inner 위임.
class _NewUserFirstApiClient implements ApiClient {
  _NewUserFirstApiClient(this._inner);
  final ApiClient _inner;
  int _meCalls = 0;
  int _thisWeekCalls = 0;

  @override
  Future<T> get<T>(String path, {Map<String, dynamic>? query}) {
    if (path == '/learning-paths/me' && _meCalls++ < 2) {
      throw const ApiException(
        code: ApiErrorCode.resourceNotFound,
        message: '아직 생성된 학습 경로가 없습니다',
        status: 404,
      );
    }
    if (path == '/learning-paths/me/this-week' && _thisWeekCalls++ == 0) {
      return Future.value(
        <String, dynamic>{
              'outcome': 'NO_ACTIVE_PATH',
              'pathId': null,
              'weekNum': null,
              'tasks': <Object?>[],
              'nextTask': null,
              'pathCompleted': false,
            }
            as T,
      );
    }
    return _inner.get<T>(path, query: query);
  }

  @override
  Future<T> post<T>(String path, {Object? body, Map<String, dynamic>? query}) =>
      _inner.post<T>(path, body: body, query: query);

  @override
  Future<T> put<T>(String path, {Object? body, Map<String, dynamic>? query}) =>
      _inner.put<T>(path, body: body, query: query);

  @override
  Future<T> delete<T>(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) => _inner.delete<T>(path, body: body, query: query);

  @override
  Stream<SseEvent> sse(String path, {Object? body}) =>
      _inner.sse(path, body: body);

  @override
  Future<T> postMultipart<T>(
    String path, {
    required List<int> bytes,
    required String filename,
    String field = 'file',
    String? contentType,
  }) => _inner.postMultipart<T>(
    path,
    bytes: bytes,
    filename: filename,
    field: field,
    contentType: contentType,
  );

  @override
  Dio get dio => _inner.dio;
}

void main() {
  testWidgets('flag OFF 회원 완료는 preview CTA 없이 legacy처럼 PATH로 자동 전환한다', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(_NoBootstrapAuthController.new),
          assessmentApiProvider.overrideWithValue(_FastCompleteAssessmentApi()),
        ],
        child: const DevPathWebApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('GitHub로 계속하기 (목)'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('diagnostic-track')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('백엔드 (Spring)').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('진단 시작하기'));
    await tester.pumpAndSettle();

    expect(find.text('진단 결과'), findsNothing);
    expect(find.byType(DiagnosticPage), findsNothing);
    expect(find.byType(PathPage), findsOneWidget);
  });

  testWidgets('로그인 → 온보딩 진단 → PATH 생성까지 게이트 흐름', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(_missionSpineOn),
          authControllerProvider.overrideWith(_NoBootstrapAuthController.new),
          assessmentApiProvider.overrideWithValue(_FastCompleteAssessmentApi()),
        ],
        child: const DevPathWebApp(),
      ),
    );
    await tester.pumpAndSettle();

    // 로그인(PENDING) → 진단
    await tester.tap(find.text('GitHub로 계속하기 (목)'));
    await tester.pumpAndSettle();
    expect(find.byType(DiagnosticPage), findsOneWidget);

    // 진단 시작 → 즉시 완료(next=null) → saved preview. 명시 CTA 뒤 PATH 생성 화면.
    // 트랙을 고르기 전에는 시작 버튼이 비활성이다.
    await tester.tap(find.byKey(const ValueKey('diagnostic-track')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('백엔드 (Spring)').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('진단 시작하기'));
    await tester.pumpAndSettle();
    expect(find.text('진단 결과'), findsOneWidget);
    await tester.tap(find.text('기존 경로로 계속'));
    await tester.pumpAndSettle();
    expect(find.byType(PathPage), findsOneWidget);

    // 목 SSE(250ms×4) 완료까지 진행(pumpAndSettle이 흡수 못하는 타이머는 명시 pump).
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Stream 구독 실습'), findsOneWidget); // 생성 완료된 이번 주 과제
  });

  testWidgets('D2: SSE 중단 주입 → "다시 생성" → 완료', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(_missionSpineOn),
          // Task 3.5: bootstrapSession microtask 없이 로그인 화면에서 시작.
          authControllerProvider.overrideWith(_NoBootstrapAuthController.new),
          assessmentApiProvider.overrideWithValue(_FastCompleteAssessmentApi()),
          // E2E 조치(loadOrStart) 정합: 신규 사용자라 첫 GET /me는 404 → start()로 생성.
          // done 후 _loadResult의 GET /me는 목 위임(생성된 경로 200).
          apiClientProvider.overrideWith(
            (ref) => _NewUserFirstApiClient(_mockInner()),
          ),
          pathSseConnectProvider.overrideWithValue(() {
            calls++;
            return MockSseSource(
              stages: kPathStages,
              delay: const Duration(milliseconds: 10),
              failAfter: calls == 1 ? 2 : null,
            ).stream();
          }),
        ],
        child: const DevPathWebApp(),
      ),
    );
    await tester.pumpAndSettle();

    // 로그인 → 진단 → 진단 시작 → 즉시 완료 → PATH 생성(중단)
    await tester.tap(find.text('GitHub로 계속하기 (목)'));
    await tester.pumpAndSettle();
    // 트랙을 고르기 전에는 시작 버튼이 비활성이다.
    await tester.tap(find.byKey(const ValueKey('diagnostic-track')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('백엔드 (Spring)').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('진단 시작하기'));
    await tester.pumpAndSettle();
    expect(find.text('진단 결과'), findsOneWidget);
    await tester.tap(find.text('학습 경로로 계속'));
    await tester.pumpAndSettle();

    // 중단 → 완료 단계 보존 + "다시 생성" 노출
    expect(find.text('다시 생성'), findsOneWidget);

    // 다시 생성 → 완료(타임라인)
    await tester.tap(find.text('다시 생성'));
    await tester.pumpAndSettle();
    expect(find.text('Stream 구독 실습'), findsOneWidget);
    expect(calls, 2);
  });

  // 2026-08-03: 위 두 테스트는 assessmentApiProvider를 즉시완료 페이크로
  // 덮어써서(next()가 항상 null) 회원 진단의 실제 목 픽스처 경로
  // (POST /onboarding/assessments, GET .../{id}/next 등)를 전혀 거치지 않는다.
  // 그 픽스처가 빠지면 회원(로그인) 사용자가 진단 화면에서 문항을 보지 못하는
  // 회귀가 생기므로, assessmentApiProvider는 덮어쓰지 않고 실제
  // webMockFixtures로만 검증한다.
  testWidgets('회원(로그인) 진단: 실제 목 픽스처로 문항이 렌더된다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(_missionSpineOn),
          authControllerProvider.overrideWith(_NoBootstrapAuthController.new),
        ],
        child: const DevPathWebApp(),
      ),
    );
    await tester.pumpAndSettle();

    // 로그인(PENDING) → 진단 화면.
    await tester.tap(find.text('GitHub로 계속하기 (목)'));
    await tester.pumpAndSettle();
    expect(find.byType(DiagnosticPage), findsOneWidget);

    // 진단 시작 → 실제 픽스처(POST /onboarding/assessments → GET .../1/next)로
    // 문항이 렌더돼야 한다(회원 경로 픽스처 누락 시 이 지점에서 막힌다).
    // 트랙을 고르기 전에는 시작 버튼이 비활성이다.
    await tester.tap(find.byKey(const ValueKey('diagnostic-track')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('백엔드 (Spring)').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('진단 시작하기'));
    await tester.pumpAndSettle();
    expect(find.text('비동기 함수의 반환 타입은 무엇인가요?'), findsOneWidget);
    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
  });

  // ★이 테스트가 이번 작업의 존재 이유다★
  // MockHttpAdapter 가 키 하나에 고정 응답 하나만 갖던 시절에는 next 가 늘 같은
  // 문항을 돌려줘 진단이 **완주하지 못했다**(2026-08-03 사용자 실측). 완료 판정은
  // next 의 본문이 null 일 때만 일어나므로(AssessmentApi.next → DiagnosticController
  // ._advance), 시퀀스 없이는 이 흐름을 목으로 재현할 수 없다.
  testWidgets('회원 진단이 문항 2개를 거쳐 완주한다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(_missionSpineOn),
          authControllerProvider.overrideWith(_NoBootstrapAuthController.new),
        ],
        child: const DevPathWebApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('GitHub로 계속하기 (목)'));
    await tester.pumpAndSettle();
    // 트랙을 고르기 전에는 시작 버튼이 비활성이다.
    await tester.tap(find.byKey(const ValueKey('diagnostic-track')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('백엔드 (Spring)').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('진단 시작하기'));
    await tester.pumpAndSettle();

    // 1번 문항 → 답변 → 2번 문항으로 **넘어가야** 한다(같은 문항이 반복되면 실패).
    expect(find.text('비동기 함수의 반환 타입은 무엇인가요?'), findsOneWidget);
    await tester.tap(find.text('A'));
    await tester.pumpAndSettle();
    expect(
      find.text('Stream 구독을 해제하지 않으면 어떤 문제가 생기나요?'),
      findsOneWidget,
      reason: '두 번째 문항이 안 나오면 next 가 같은 응답을 반복하는 것이다',
    );

    // 2번 답변 → next 가 null → complete → 결과 preview에 머문다.
    await tester.tap(find.text('A'));
    await tester.pumpAndSettle();
    expect(
      find.text('진단 결과'),
      findsOneWidget,
      reason: 'complete 뒤 저장된 결과를 먼저 보여줘야 한다',
    );
    await tester.tap(find.text('기존 경로로 계속'));
    await tester.pumpAndSettle();
    expect(find.byType(DiagnosticPage), findsNothing);
  });
}
