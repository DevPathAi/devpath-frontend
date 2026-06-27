import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../app/app_config.dart';
import '../auth/secure_storage_token_store.dart';
import '../data/key_value_store.dart';
import '../data/mobile_mock_fixtures.dart';
import '../data/secure_key_value_store.dart';

final appConfigProvider = Provider<AppConfig>(
  (ref) => AppConfig.fromEnvironment(),
);

/// secure_storage 인스턴스(테스트는 [keyValueStoreProvider] 오버라이드로 회피).
final secureStorageProvider = Provider<FlutterSecureStorage>(
  (ref) => const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  ),
);

final keyValueStoreProvider = Provider<KeyValueStore>(
  (ref) => SecureKeyValueStore(ref.watch(secureStorageProvider)),
);

final tokenStoreProvider = Provider<TokenStore>(
  (ref) => SecureStorageTokenStore(ref.watch(keyValueStoreProvider)),
);

/// dp_core ApiClient + 모바일 토큰 기반 401 refresh 인터셉터.
/// 목 모드면 [MockHttpAdapter]를 장착한다(웹과 동일 패턴).
final apiClientProvider = Provider<ApiClient>((ref) {
  final config = ref.watch(appConfigProvider);
  final store = ref.watch(tokenStoreProvider);
  final client = ApiClient.create(
    ApiConfig(baseUrl: config.baseUrl, useMock: config.useMock),
  );

  client.dio.interceptors.insert(
    0,
    AuthInterceptor(
      store: store,
      // 모바일: 저장된 refresh 토큰을 바디로 전송(백엔드 토큰-바디 계약, 후속).
      refresh: (refreshToken) async {
        if (refreshToken == null || refreshToken.isEmpty) return null;
        final data = await client.post<Map<String, dynamic>>(
          '/auth/refresh',
          body: {'refresh_token': refreshToken},
        );
        return TokenPair(
          access: data['access_token'] as String,
          refresh: (data['refresh_token'] as String?) ?? refreshToken,
        );
      },
      retry: (options) => client.dio.fetch(options),
    ),
  );

  if (config.useMock) {
    client.dio.httpClientAdapter = MockHttpAdapter(mobileMockFixtures);
  }
  return client;
});
