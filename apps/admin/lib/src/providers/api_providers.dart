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
  final client = ApiClient.create(
    ApiConfig(baseUrl: config.baseUrl, useMock: config.useMock),
  );
  if (config.useMock) {
    client.dio.httpClientAdapter = MockHttpAdapter(adminMockFixtures);
  }
  return client;
});
