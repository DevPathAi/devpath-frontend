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
/// 401 큐잉 AuthInterceptor 결선은 인증 데이터 호출이 생기는 P4b에서 추가.
final apiClientProvider = Provider<ApiClient>((ref) {
  final config = ref.watch(appConfigProvider);
  final client = ApiClient.create(
    ApiConfig(baseUrl: config.baseUrl, useMock: config.useMock),
  );
  if (config.useMock) {
    client.dio.httpClientAdapter = MockHttpAdapter(webMockFixtures);
  }
  return client;
});
