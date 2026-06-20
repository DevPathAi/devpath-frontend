import 'package:devpath_web/src/providers/api_providers.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // POST /auth/login 픽스처는 실흐름에 없으므로 제거됨(Task 4).
  // 실흐름: OAuth 리다이렉트 → 콜백 → POST /auth/refresh → 세션 복원.
  test('목 모드 apiClient는 /auth/refresh 픽스처를 반환한다', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final client = container.read(apiClientProvider);
    final data = await client.post<Map<String, dynamic>>('/auth/refresh');

    expect(data['access_token'], isNotEmpty);
    expect(data['refresh_token_cookie_set'], isTrue);
    expect((data['user'] as Map)['nickname'], '지수');
  });

  test('tokenStore는 InMemory 기본 구현이다', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(tokenStoreProvider), isA<InMemoryTokenStore>());
  });
}
