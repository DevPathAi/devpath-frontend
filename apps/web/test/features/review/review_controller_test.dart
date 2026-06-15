import 'package:devpath_web/src/features/review/application/review_controller.dart';
import 'package:devpath_web/src/features/review/state/review_state.dart';
import 'package:devpath_web/src/providers/api_providers.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 'POST /reviews'에 지정 응답을 주는 ApiClient 오버라이드 헬퍼.
ApiClient _client(int status, Object body) {
  final c = ApiClient.create(const ApiConfig(baseUrl: 'https://t/api/v1'));
  c.dio.httpClientAdapter = MockHttpAdapter({'POST /reviews': (status, body)});
  return c;
}

void main() {
  test('성공 시 ReviewLoaded', () async {
    final c = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(
          _client(200, {
            'confidence': 90,
            'strengths': ['좋음'],
            'improvements': <Map<String, dynamic>>[],
            'security': <Map<String, dynamic>>[],
          }),
        ),
      ],
    );
    addTearDown(c.dispose);

    await c.read(reviewControllerProvider.notifier).request('code');
    final s = c.read(reviewControllerProvider);
    expect(s, isA<ReviewLoaded>());
    expect((s as ReviewLoaded).review.confidence, 90);
  });

  test('AI_KILL_SWITCH_ACTIVE → ReviewKillSwitch', () async {
    final c = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(
          _client(503, {
            'error': {'code': 'AI_KILL_SWITCH_ACTIVE', 'message': '점검'},
          }),
        ),
      ],
    );
    addTearDown(c.dispose);
    await c.read(reviewControllerProvider.notifier).request('code');
    expect(c.read(reviewControllerProvider), isA<ReviewKillSwitch>());
  });

  test('QUOTA_EXCEEDED → ReviewQuota(retryAfter)', () async {
    final client = ApiClient.create(
      const ApiConfig(baseUrl: 'https://t/api/v1'),
    );
    // Retry-After 헤더 포함 응답
    client.dio.httpClientAdapter = MockHttpAdapter({
      'POST /reviews': (
        429,
        {
          'error': {'code': 'QUOTA_EXCEEDED', 'message': '한도'},
        },
      ),
    });
    final c = ProviderContainer(
      overrides: [apiClientProvider.overrideWithValue(client)],
    );
    addTearDown(c.dispose);
    await c.read(reviewControllerProvider.notifier).request('code');
    expect(c.read(reviewControllerProvider), isA<ReviewQuota>());
  });
}
