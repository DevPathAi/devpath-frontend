import 'package:devpath_web/src/app/app.dart';
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

/// 목 모드 ApiClient(web 픽스처). 페이크의 위임 대상(api_providers와 동일 구성).
ApiClient _mockInner() {
  final inner = ApiClient.create(const ApiConfig(baseUrl: '', useMock: true));
  inner.dio.httpClientAdapter = MockHttpAdapter(webMockFixtures);
  return inner;
}

/// D2 신규 사용자: `GET /learning-paths/me`를 **첫 호출엔 404**(경로 없음),
/// 이후엔 목 inner에 위임(생성된 경로 200). loadOrStart가 첫 404를 받아 start()로
/// 생성 흐름(SSE 중단→다시 생성)을 타게 한다. 나머지(post/sse/dio)는 inner 위임.
class _NewUserFirstApiClient implements ApiClient {
  _NewUserFirstApiClient(this._inner);
  final ApiClient _inner;
  int _meCalls = 0;

  @override
  Future<T> get<T>(String path, {Map<String, dynamic>? query}) {
    if (path == '/learning-paths/me' && _meCalls++ == 0) {
      throw const ApiException(
        code: ApiErrorCode.resourceNotFound,
        message: '아직 생성된 학습 경로가 없습니다',
        status: 404,
      );
    }
    return _inner.get<T>(path, query: query);
  }

  @override
  Future<T> post<T>(String path, {Object? body, Map<String, dynamic>? query}) =>
      _inner.post<T>(path, body: body, query: query);

  @override
  Stream<SseEvent> sse(String path, {Object? body}) =>
      _inner.sse(path, body: body);

  @override
  Dio get dio => _inner.dio;
}

void main() {
  testWidgets('로그인 → 온보딩 진단 → PATH 생성까지 게이트 흐름', (tester) async {
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

    // 로그인(PENDING) → 진단
    await tester.tap(find.text('GitHub로 계속하기 (목)'));
    await tester.pumpAndSettle();
    expect(find.byType(DiagnosticPage), findsOneWidget);

    // 진단 시작 → 즉시 완료(next=null) → DiagnosticResultState → PATH 생성 화면
    await tester.tap(find.text('진단 시작하기'));
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
    await tester.tap(find.text('진단 시작하기'));
    await tester.pumpAndSettle();

    // 중단 → 완료 단계 보존 + "다시 생성" 노출
    expect(find.text('다시 생성'), findsOneWidget);

    // 다시 생성 → 완료(타임라인)
    await tester.tap(find.text('다시 생성'));
    await tester.pumpAndSettle();
    expect(find.text('Stream 구독 실습'), findsOneWidget);
    expect(calls, 2);
  });
}
