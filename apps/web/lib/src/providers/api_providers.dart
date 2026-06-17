import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/app_config.dart';
import '../data/web_mock_fixtures.dart';

final appConfigProvider = Provider<AppConfig>(
  (ref) => AppConfig.fromEnvironment(),
);

/// 프로토: web 토큰은 메모리(스펙 §3 "web=httpOnly 쿠키/메모리" 중 메모리).
/// localStorage 영속화는 후속(리스크 참조).
final tokenStoreProvider = Provider<TokenStore>((ref) => InMemoryTokenStore());

/// dio 래퍼. 목 모드면 MockHttpAdapter 주입(백엔드 없이 동작).
final apiClientProvider = Provider<ApiClient>((ref) {
  final config = ref.watch(appConfigProvider);
  final store = ref.watch(tokenStoreProvider);
  final client = ApiClient.create(
    ApiConfig(baseUrl: config.baseUrl, useMock: config.useMock),
  );
  // withCredentials: true — 웹 XHR이 HttpOnly 쿠키를 자동 전송하도록 설정.
  // BrowserHttpClientAdapter는 options.extra['withCredentials']를 per-request로 참조한다.
  // BaseOptions.extra에 설정하면 모든 요청에 일괄 적용된다.
  client.dio.options.extra['withCredentials'] = true;

  // ENG-REVIEW D1: 401 큐잉 AuthInterceptor(P2) 결선 — onRequest Bearer 주입 + onError refresh/retry.
  // ApiClient.create가 에러 정규화 인터셉터를 마지막에 추가하므로, 그 앞(index 0)에 삽입한다.
  client.dio.interceptors.insert(
    0,
    AuthInterceptor(
      store: store,
      // refresh 콜백: 쿠키 기반 — 본문 없이 POST /auth/refresh(HttpOnly 쿠키 자동 전송).
      // 응답은 최상위 access_token(snake_case). refresh 토큰은 HttpOnly 쿠키가 보유하므로
      // TokenPair.refresh는 빈 문자열로 반환한다(InMemoryTokenStore에 저장되지만 무시됨).
      refresh: (refreshToken) async {
        final data = await client.post<Map<String, dynamic>>('/auth/refresh');
        return TokenPair(
          access: data['access_token'] as String,
          refresh: '',
        );
      },
      retry: (options) => client.dio.fetch(options),
    ),
  );

  if (config.useMock) {
    client.dio.httpClientAdapter = MockHttpAdapter(webMockFixtures);
  }
  return client;
});
