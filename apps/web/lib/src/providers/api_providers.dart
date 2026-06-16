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

  // ENG-REVIEW D1: 401 큐잉 AuthInterceptor(P2) 결선 — onRequest Bearer 주입 + onError refresh/retry.
  // ApiClient.create가 에러 정규화 인터셉터를 마지막에 추가하므로, 그 앞(index 0)에 삽입한다.
  client.dio.interceptors.insert(
    0,
    AuthInterceptor(
      store: store,
      refresh: (refreshToken) async {
        final data = await client.post<Map<String, dynamic>>(
          '/auth/refresh',
          body: {'refreshToken': refreshToken},
        );
        return TokenPair(
          access: data['accessToken'] as String,
          refresh: data['refreshToken'] as String,
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
