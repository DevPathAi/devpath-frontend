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
      // admin 토큰 refresh 엔드포인트는 아직 미정의(login만 존재) → null 반환:
      // 401 시 store.clear + 에러 전파로 재로그인을 유도한다. 자동 갱신 배선은
      // 백엔드 admin refresh 엔드포인트 확정 후 후속.
      refresh: (refreshToken) async => null,
      retry: (options) => client.dio.fetch(options),
    ),
  );

  if (config.useMock) {
    client.dio.httpClientAdapter = MockHttpAdapter(adminMockFixtures);
  }
  return client;
});
