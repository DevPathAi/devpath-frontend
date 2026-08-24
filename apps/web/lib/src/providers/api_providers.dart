import 'dart:convert';

import 'package:dp_core/dp_core.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../analytics/analytics_contract.dart';
import '../analytics/journey_analytics.dart';
import '../analytics/journey_handoff.dart';
import '../analytics/analytics_runtime.dart';
import '../analytics/release_analytics.dart';
import '../analytics/release_analytics_runtime.dart';
import '../app/app_config.dart';
import '../data/web_mock_fixtures.dart';
import '../features/auth/application/auth_controller.dart';
import 'onboarding_gate_interceptor.dart';

final appConfigProvider = Provider<AppConfig>(
  (ref) => AppConfig.fromEnvironment(),
);

/// Required operational input before analytics is enabled: override this with
/// an authoritative internal/test-account claim or registry. The current auth
/// model exposes neither, so the opted-out default stays in force; email,
/// nickname, provider subject, or a locally invented allowlist must not be used.
final analyticsInternalUserPolicyProvider =
    Provider<InternalAnalyticsUserPolicy>(
      (ref) =>
          (_) => false,
    );

final journeyIdStoreProvider = Provider<JourneyIdStore>(
  (ref) => journeyIdStore(),
);
final analyticsSessionIdStoreProvider = Provider<JourneyIdStore>(
  (ref) => analyticsSessionIdStore(),
);
final analyticsIdGeneratorProvider = Provider<String Function()>(
  (ref) => generateOpaqueJourneyId,
);
final analyticsUserAgentProvider = Provider<String>(
  (ref) => analyticsRuntimeUserAgent(),
);
final releaseAnalyticsMarkerProvider = Provider<ReleaseAnalyticsMarker?>(
  (ref) => parseReleaseAnalyticsMarker(readReleaseAnalyticsMarkerValue()),
);
final releaseAnalyticsDioProvider = Provider<Dio>((ref) => Dio());

/// Vendor-neutral, opt-out default. ET1 deliberately installs no vendor SDK.
final journeyAnalyticsProvider = Provider<JourneyAnalytics>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.analyticsContractVersion != analyticsContractVersion) {
    return const OptedOutJourneyAnalytics();
  }
  try {
    final marker = ref.watch(releaseAnalyticsMarkerProvider);
    final releaseMode =
        marker != null &&
        config.analyticsEnvironment == 'production' &&
        config.appVersion != 'dev';
    final generator = ref.watch(analyticsIdGeneratorProvider);
    final journeyId = getOrCreateJourneyId(
      ref.watch(journeyIdStoreProvider),
      randomBytes: (_) => _decodeGeneratedId(generator()),
    );
    final sessionId = getOrCreateJourneyId(
      ref.watch(analyticsSessionIdStoreProvider),
      randomBytes: (_) => _decodeGeneratedId(generator()),
    );
    return JourneyAnalyticsAdapter(
      sdk: releaseMode
          ? ReleaseJourneyAnalyticsSdk(
              marker,
              ref.watch(releaseAnalyticsDioProvider),
            )
          : const NoopJourneyAnalyticsSdk(),
      context: JourneyAnalyticsContext(
        environment: config.analyticsEnvironment,
        appVersion: config.appVersion,
        sessionId: sessionId,
        journeyId: journeyId,
      ),
      optedOut: !releaseMode,
      excluded:
          !releaseMode &&
          shouldExcludeAnalyticsTraffic(
            environment: config.analyticsEnvironment,
            appVersion: config.appVersion,
            userAgent: ref.watch(analyticsUserAgentProvider),
          ),
      isInternalUser: ref.watch(analyticsInternalUserPolicyProvider),
    );
  } catch (_) {
    return const OptedOutJourneyAnalytics();
  }
});

List<int> _decodeGeneratedId(String value) {
  // Provider seam accepts the final ID so tests can model secure-random denial.
  // getOrCreateJourneyId expects bytes, so decode the validated base64url value.
  if (!isValidJourneyId(value)) throw StateError('invalid analytics id');
  final padded = value.padRight(24, '=');
  return base64Url.decode(padded);
}

/// 프로토: web 토큰은 메모리(스펙 §3 "web=httpOnly 쿠키/메모리" 중 메모리).
/// localStorage 영속화는 후속(리스크 참조).
final tokenStoreProvider = Provider<TokenStore>((ref) => InMemoryTokenStore());

/// 최근 API 실패 링버퍼. 제보 다이얼로그가 읽고, 인터셉터가 쓴다.
/// 메모리 전용이라 새로고침하면 비어 있다.
final apiFailureLogProvider = Provider<ApiFailureLog>((ref) => ApiFailureLog());

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
    client.dio.httpClientAdapter = MockHttpAdapter(
      webMockFixtures,
      sequences: webMockSequences,
    );
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

  // 제보용 실패 기록 — **Auth 뒤 · ErrorNormalizer 앞**.
  // index 0 이면 Auth 가 refresh 로 복구하는 일시적 401까지 기록되어, 사용자가 겪지도
  // 않은 실패가 제보에 섞인다. 정규화 뒤면 handler.reject() 로 체인이 끝나 아무것도 못 본다.
  // dp_core 의 api_failure_recorder_test 가 "정규화가 마지막"이라는 이 불변식을 지킨다.
  client.dio.interceptors.insert(
    client.dio.interceptors.length - 1,
    ApiFailureRecorder(ref.watch(apiFailureLogProvider)),
  );

  if (config.useMock) {
    client.dio.httpClientAdapter = MockHttpAdapter(
      webMockFixtures,
      sequences: webMockSequences,
    );
  }
  return client;
});

/// Web의 Riverpod·캐시 정책과 분리된 공용 학습 경로 wire client.
///
/// Dashboard/Today와 이후 Path/mobile consumer가 endpoint 문자열이나 JSON을
/// 다시 해석하지 않고 dp_core의 동일한 typed contract를 사용한다.
final learningPathApiProvider = Provider<LearningPathApi>(
  (ref) => LearningPathApi(ref.watch(apiClientProvider)),
);
