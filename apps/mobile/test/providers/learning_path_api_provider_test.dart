import 'package:devpath_mobile/src/providers/api_providers.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('LearningPathApi provider는 인증 ApiClient 인스턴스를 그대로 쓴다', () {
    final client = ApiClient.create(
      const ApiConfig(baseUrl: 'https://api.example.test'),
    );
    final container = ProviderContainer(
      overrides: [apiClientProvider.overrideWithValue(client)],
    );
    addTearDown(container.dispose);

    final api = container.read(learningPathApiProvider);

    expect(api.client, same(client));
  });
}
