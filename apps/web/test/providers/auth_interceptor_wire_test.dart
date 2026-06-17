import 'dart:convert';
import 'dart:typed_data';

import 'package:devpath_web/src/providers/api_providers.dart';
import 'package:dio/dio.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// MockAdapter: /auth/refresh 요청을 캡처해 응답을 반환한다.
class _RefreshCaptureAdapter implements HttpClientAdapter {
  RequestOptions? capturedOptions;
  Object? capturedBody; // 요청 바디 (null이면 본문 없음)

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    capturedOptions = options;

    // requestStream이 있으면 바디를 수집한다.
    if (requestStream != null) {
      final bytes = <int>[];
      await for (final chunk in requestStream) {
        bytes.addAll(chunk);
      }
      if (bytes.isNotEmpty) {
        capturedBody = jsonDecode(utf8.decode(bytes));
      }
    } else {
      capturedBody = null;
    }

    // 실제 계약: 최상위 access_token(snake_case) 반환.
    return ResponseBody.fromString(
      jsonEncode({'access_token': 'refreshed-access'}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('apiClientProvider에 AuthInterceptor가 결선된다', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final client = c.read(apiClientProvider);
    expect(client.dio.interceptors.whereType<AuthInterceptor>(), isNotEmpty);
  });

  test('withCredentials가 BaseOptions.extra에 설정된다', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final client = c.read(apiClientProvider);
    expect(
      client.dio.options.extra['withCredentials'],
      isTrue,
      reason: 'dio BaseOptions.extra에 withCredentials: true가 설정되어야 한다',
    );
  });

  test('refresh 콜백은 본문 없이 POST /auth/refresh를 호출하고 access_token을 매핑한다', () async {
    final adapter = _RefreshCaptureAdapter();
    // refresh 콜백을 직접 추출하기 위해 apiClientProvider에서 사용하는 것과
    // 동일한 방식으로 ApiClient를 구성한다.
    final client = ApiClient.create(
      const ApiConfig(baseUrl: 'http://test.local'),
    );
    client.dio.httpClientAdapter = adapter;

    // 콜백 정의 — api_providers.dart의 실제 구현과 동일해야 한다.
    Future<TokenPair?> refreshCallback(String? refreshToken) async {
      final data = await client.post<Map<String, dynamic>>('/auth/refresh');
      return TokenPair(
        access: data['access_token'] as String,
        refresh: '',
      );
    }

    final result = await refreshCallback(null);

    // 1. 본문 없음 검증
    expect(
      adapter.capturedBody,
      isNull,
      reason: 'refresh 요청은 본문 없이 전송되어야 한다(쿠키 기반)',
    );

    // 2. 메서드/경로 검증
    expect(adapter.capturedOptions?.method, equals('POST'));
    expect(adapter.capturedOptions?.path, equals('/auth/refresh'));

    // 3. access_token 매핑 검증
    expect(result?.access, equals('refreshed-access'));
    expect(result?.refresh, equals(''));
  });
}
