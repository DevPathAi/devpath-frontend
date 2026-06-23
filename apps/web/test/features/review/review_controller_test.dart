import 'dart:convert';
import 'dart:typed_data';

import 'package:devpath_web/src/features/review/application/review_controller.dart';
import 'package:devpath_web/src/features/review/state/review_state.dart';
import 'package:devpath_web/src/providers/api_providers.dart';
import 'package:dio/dio.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 순차 응답 목 어댑터(PENDING → DONE 전이 시뮬레이션).
class _SequentialMockAdapter implements HttpClientAdapter {
  _SequentialMockAdapter(this._responses);
  final List<Map<String, dynamic>> _responses;
  int _i = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    final r = _responses[_i.clamp(0, _responses.length - 1)];
    _i++;
    return ResponseBody.fromString(
      jsonEncode(r),
      200,
      headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('polls until DONE then ReviewLoaded', () async {
    final client = ApiClient.create(
      const ApiConfig(baseUrl: 'https://t/api/v1'),
    );
    client.dio.httpClientAdapter = _SequentialMockAdapter([
      {
        'status': 'PENDING',
        'confidence': 0,
        'strengths': <String>[],
        'improvements': <Map<String, dynamic>>[],
        'security': <Map<String, dynamic>>[],
      },
      {
        'status': 'DONE',
        'confidence': 88,
        'strengths': ['clear'],
        'improvements': <Map<String, dynamic>>[],
        'security': <Map<String, dynamic>>[],
      },
    ]);
    final container = ProviderContainer(
      overrides: [apiClientProvider.overrideWithValue(client)],
    );
    addTearDown(container.dispose);

    await container
        .read(reviewControllerProvider.notifier)
        .pollForSession(
          99,
          interval: const Duration(milliseconds: 1),
          maxAttempts: 5,
        );

    final s = container.read(reviewControllerProvider);
    expect(s, isA<ReviewLoaded>());
    expect((s as ReviewLoaded).review.confidence, 88);
  });

  test('FAILED status → ReviewFailed', () async {
    final client = ApiClient.create(
      const ApiConfig(baseUrl: 'https://t/api/v1'),
    );
    client.dio.httpClientAdapter = _SequentialMockAdapter([
      {
        'status': 'FAILED',
        'confidence': 0,
        'strengths': <String>[],
        'improvements': <Map<String, dynamic>>[],
        'security': <Map<String, dynamic>>[],
      },
    ]);
    final container = ProviderContainer(
      overrides: [apiClientProvider.overrideWithValue(client)],
    );
    addTearDown(container.dispose);

    await container
        .read(reviewControllerProvider.notifier)
        .pollForSession(
          1,
          interval: const Duration(milliseconds: 1),
          maxAttempts: 3,
        );

    expect(container.read(reviewControllerProvider), isA<ReviewFailed>());
  });

  test('timeout (maxAttempts exhausted) → ReviewFailed with 초과', () async {
    final client = ApiClient.create(
      const ApiConfig(baseUrl: 'https://t/api/v1'),
    );
    // 항상 PENDING 반환 → maxAttempts 소진 후 ReviewFailed
    client.dio.httpClientAdapter = _SequentialMockAdapter([
      for (var i = 0; i < 5; i++)
        {
          'status': 'PENDING',
          'confidence': 0,
          'strengths': <String>[],
          'improvements': <Map<String, dynamic>>[],
          'security': <Map<String, dynamic>>[],
        },
    ]);
    final container = ProviderContainer(
      overrides: [apiClientProvider.overrideWithValue(client)],
    );
    addTearDown(container.dispose);

    await container
        .read(reviewControllerProvider.notifier)
        .pollForSession(
          1,
          interval: const Duration(milliseconds: 1),
          maxAttempts: 3,
        );

    final s = container.read(reviewControllerProvider);
    expect(s, isA<ReviewFailed>());
    expect((s as ReviewFailed).message, contains('초과'));
  });

  test('AI_KILL_SWITCH_ACTIVE → ReviewKillSwitch', () async {
    final c = ApiClient.create(const ApiConfig(baseUrl: 'https://t/api/v1'));
    c.dio.httpClientAdapter = MockHttpAdapter({
      'GET /reviews': (
        503,
        {'error': {'code': 'AI_KILL_SWITCH_ACTIVE', 'message': '점검'}},
      ),
    });
    final container = ProviderContainer(
      overrides: [apiClientProvider.overrideWithValue(c)],
    );
    addTearDown(container.dispose);

    await container
        .read(reviewControllerProvider.notifier)
        .pollForSession(
          1,
          interval: const Duration(milliseconds: 1),
          maxAttempts: 3,
        );

    expect(container.read(reviewControllerProvider), isA<ReviewKillSwitch>());
  });

  test('QUOTA_EXCEEDED → ReviewQuota', () async {
    final c = ApiClient.create(const ApiConfig(baseUrl: 'https://t/api/v1'));
    c.dio.httpClientAdapter = MockHttpAdapter({
      'GET /reviews': (
        429,
        {'error': {'code': 'QUOTA_EXCEEDED', 'message': '한도'}},
      ),
    });
    final container = ProviderContainer(
      overrides: [apiClientProvider.overrideWithValue(c)],
    );
    addTearDown(container.dispose);

    await container
        .read(reviewControllerProvider.notifier)
        .pollForSession(
          1,
          interval: const Duration(milliseconds: 1),
          maxAttempts: 3,
        );

    expect(container.read(reviewControllerProvider), isA<ReviewQuota>());
  });
}
