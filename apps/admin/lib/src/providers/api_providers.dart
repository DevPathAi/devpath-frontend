import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/app_config.dart';
import '../data/admin_mock_fixtures.dart';

final appConfigProvider = Provider<AppConfig>(
  (ref) => AppConfig.fromEnvironment(),
);
final tokenStoreProvider = Provider<TokenStore>((ref) => InMemoryTokenStore());

final apiClientProvider = Provider<ApiClient>((ref) {
  final config = ref.watch(appConfigProvider);
  final store = ref.watch(tokenStoreProvider);
  final client = ApiClient.create(
    ApiConfig(baseUrl: config.baseUrl, useMock: config.useMock),
  );

  // admin은 토큰 기반(Bearer). tokenStore의 access를 onRequest에 주입하지 않으면 실서버 모드에서
  // Authorization 헤더가 빠져 401이 난다(mock 모드라 그간 미발현). web 패턴대로 AuthInterceptor를
  // 에러 정규화 인터셉터(ApiClient.create가 마지막에 추가) 앞(index 0)에 삽입한다.
  client.dio.interceptors.insert(
    0,
    AuthInterceptor(
      store: store,
      // refresh 콜백: 쿠키 기반 — 본문 없이 POST /auth/refresh(HttpOnly 쿠키 자동 전송,
      // withCredentials=true). 응답 최상위 access_token(snake_case). refresh 토큰은
      // HttpOnly 쿠키가 보유하므로 TokenPair.refresh는 빈 문자열(web 패턴과 동일).
      refresh: (refreshToken) async {
        final data = await client.post<Map<String, dynamic>>('/auth/refresh');
        return TokenPair(access: data['access_token'] as String, refresh: '');
      },
      retry: (options) => client.dio.fetch(options),
    ),
  );

  client.dio.options.extra['withCredentials'] = true;

  if (config.useMock) {
    client.dio.httpClientAdapter = MockHttpAdapter(adminMockFixtures);
  }
  return client;
});
