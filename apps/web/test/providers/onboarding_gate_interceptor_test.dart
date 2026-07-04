import 'dart:convert';
import 'dart:typed_data';

import 'package:devpath_web/src/providers/api_providers.dart';
import 'package:devpath_web/src/providers/onboarding_gate_interceptor.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.statusCode, this.body);
  final int statusCode;
  final String body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      body,
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio _dioWith(_StubAdapter adapter, void Function() onIncomplete) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test.local'))
    ..httpClientAdapter = adapter
    ..interceptors.add(OnboardingGateInterceptor(onIncomplete));
  return dio;
}

void main() {
  test('403 ONBOARDING_INCOMPLETE에서 콜백을 호출한다', () async {
    var called = false;
    final dio = _dioWith(
      _StubAdapter(
        403,
        jsonEncode({
          'error': {'code': 'ONBOARDING_INCOMPLETE', 'message': '온보딩 필요'},
        }),
      ),
      () => called = true,
    );
    await expectLater(
      dio.get<dynamic>('/protected'),
      throwsA(isA<DioException>()),
    );
    expect(called, isTrue);
  });

  test('다른 403(FORBIDDEN)에서는 콜백을 호출하지 않는다', () async {
    var called = false;
    final dio = _dioWith(
      _StubAdapter(
        403,
        jsonEncode({
          'error': {'code': 'FORBIDDEN', 'message': '금지'},
        }),
      ),
      () => called = true,
    );
    await expectLater(
      dio.get<dynamic>('/protected'),
      throwsA(isA<DioException>()),
    );
    expect(called, isFalse);
  });

  test('apiClientProvider에 OnboardingGateInterceptor가 결선된다', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final client = c.read(apiClientProvider);
    expect(
      client.dio.interceptors.whereType<OnboardingGateInterceptor>(),
      isNotEmpty,
    );
  });
}
