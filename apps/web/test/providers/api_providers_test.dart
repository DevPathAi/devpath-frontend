import 'package:devpath_web/src/providers/api_providers.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('목 모드 apiClient는 로그인 픽스처를 반환한다', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final client = container.read(apiClientProvider);
    final data = await client.post<Map<String, dynamic>>('/auth/login');

    expect(data['accessToken'], isNotEmpty);
    expect((data['user'] as Map)['nickname'], '지수');
  });

  test('tokenStore는 InMemory 기본 구현이다', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(tokenStoreProvider), isA<InMemoryTokenStore>());
  });
}
