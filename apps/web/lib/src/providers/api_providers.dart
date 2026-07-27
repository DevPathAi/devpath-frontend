import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/app_config.dart';
import '../data/web_mock_fixtures.dart';
import '../features/auth/application/auth_controller.dart';
import 'onboarding_gate_interceptor.dart';

final appConfigProvider = Provider<AppConfig>(
  (ref) => AppConfig.fromEnvironment(),
);

/// 프로토: web 토큰은 메모리(스펙 §3 "web=httpOnly 쿠키/메모리" 중 메모리).
/// localStorage 영속화는 후속(리스크 참조).
final tokenStoreProvider = Provider<TokenStore>((ref) => InMemoryTokenStore());

/// refresh/재시도 전용 클라이언트 — **AuthInterceptor를 절대 장착하지 않는다.**
///
/// AuthInterceptor는 QueuedInterceptor(에러 콜백 직렬화)라서, onError 안에서 같은
/// dio로 /auth/refresh를 재호출하면 그 refresh가 401일 때 에러 콜백이 자기 큐가
/// 비기를 기다리는 순환 대기(교착)가 된다 → 무인증 부팅 시 bootstrapSession이
/// 영원히 미완결되어 /login에 도달하지 못하는 무한 스피너(2026-07-27 운영 실측).
/// dp_core auth_interceptor_test의 '큐잉' 테스트가 같은 이유로 재시도를 별도 dio로
/// 수행한다. 이 클라이언트는 그 격리를 프로덕션 배선에 적용한 것이다.
final authFlowClientProvider = Provider<ApiClient>((ref) {
  final config = ref.watch(appConfigProvider);
  final client = ApiClient.create(
    ApiConfig(baseUrl: config.baseUrl, useMock: config.useMock),
  );
  // refresh는 HttpOnly 쿠키 전송이 필요하다(메인 클라이언트와 동일).
  client.dio.options.extra['withCredentials'] = true;
  // 재시도 응답의 403 ONBOARDING_INCOMPLETE 의미 보존(메인 클라이언트와 동일 훅).
  client.dio.interceptors.insert(
    0,
    OnboardingGateInterceptor(
      () =>
          ref.read(authControllerProvider.notifier).markOnboardingIncomplete(),
    ),
  );
  if (config.useMock) {
    client.dio.httpClientAdapter = MockHttpAdapter(webMockFixtures);
  }
  return client;
});

/// dio 래퍼. 목 모드면 MockHttpAdapter 주입(백엔드 없이 동작).
final apiClientProvider = Provider<ApiClient>((ref) {
  final config = ref.watch(appConfigProvider);
  final store = ref.watch(tokenStoreProvider);
  final authFlow = ref.watch(authFlowClientProvider);
  final client = ApiClient.create(
    ApiConfig(baseUrl: config.baseUrl, useMock: config.useMock),
  );
  // withCredentials: true — 웹 XHR이 HttpOnly 쿠키를 자동 전송하도록 설정.
  // BrowserHttpClientAdapter는 options.extra['withCredentials']를 per-request로 참조한다.
  // BaseOptions.extra에 설정하면 모든 요청에 일괄 적용된다.
  client.dio.options.extra['withCredentials'] = true;

  // ENG-REVIEW D1: 401 큐잉 AuthInterceptor(P2) 결선 — onRequest Bearer 주입 + onError refresh/retry.
  // ApiClient.create가 에러 정규화 인터셉터를 마지막에 추가하므로, 그 앞(index 0)에 삽입한다.
  // refresh·retry는 반드시 authFlow(무-AuthInterceptor) 클라이언트로 수행한다(교착 방지 — 위 참조).
  client.dio.interceptors.insert(
    0,
    AuthInterceptor(
      store: store,
      // refresh 콜백: 쿠키 기반 — 본문 없이 POST /auth/refresh(HttpOnly 쿠키 자동 전송).
      // 응답은 최상위 access_token(snake_case). refresh 토큰은 HttpOnly 쿠키가 보유하므로
      // TokenPair.refresh는 빈 문자열로 반환한다(InMemoryTokenStore에 저장되지만 무시됨).
      refresh: (refreshToken) async {
        final data = await authFlow.post<Map<String, dynamic>>('/auth/refresh');
        return TokenPair(access: data['access_token'] as String, refresh: '');
      },
      retry: (options) => authFlow.dio.fetch(options),
    ),
  );

  // 라이브 403 ONBOARDING_INCOMPLETE → 온보딩 게이트 재평가.
  // ref.read은 에러 발생 시점(지연)에 실행되므로 build-time 순환 의존이 없다
  // (AuthInterceptor의 refresh 콜백과 동일 패턴 — auth는 api를 의존하지만
  //  api는 빌드 시점에 auth를 읽지 않는다).
  client.dio.interceptors.insert(
    0,
    OnboardingGateInterceptor(
      () =>
          ref.read(authControllerProvider.notifier).markOnboardingIncomplete(),
    ),
  );

  if (config.useMock) {
    client.dio.httpClientAdapter = MockHttpAdapter(webMockFixtures);
  }
  return client;
});
