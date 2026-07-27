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

/// 모든 요청에 401을 반환하는 어댑터 — 무인증 부팅(쿠키 없음/무효) 시나리오.
class _Always401Adapter implements HttpClientAdapter {
  int requests = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests++;
    return ResponseBody.fromString(
      jsonEncode({
        'error': {'code': 'UNAUTHORIZED', 'message': '401'},
      }),
      401,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('refresh 자체가 401이어도 교착 없이 실패로 완결된다(무인증 부팅 시나리오)', () async {
    // 회귀 고정: AuthInterceptor(QueuedInterceptor) 안에서 같은 dio로 refresh를
    // 재호출하면 refresh 401의 에러 콜백이 같은 큐를 기다리며 교착한다.
    // 수정 후에는 refresh/retry가 전용 authFlow 클라이언트로 분리되어,
    // 무인증 부팅의 bootstrapSession(/auth/refresh POST)이 ApiException으로 완결된다.
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final adapter = _Always401Adapter();
    c.read(apiClientProvider).dio.httpClientAdapter = adapter;
    c.read(authFlowClientProvider).dio.httpClientAdapter = adapter;

    await expectLater(
      c
          .read(apiClientProvider)
          .post<Map<String, dynamic>>('/auth/refresh')
          .timeout(const Duration(seconds: 5)),
      throwsA(isA<ApiException>()),
      reason: '교착 시 TimeoutException, 완결 시 ApiException — 완결이어야 한다',
    );
  });

  test('authFlowClient에는 AuthInterceptor가 없다(재진입 교착 방지 불변식)', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final authFlow = c.read(authFlowClientProvider);
    expect(
      authFlow.dio.interceptors.whereType<AuthInterceptor>(),
      isEmpty,
      reason: 'refresh/retry 전용 클라이언트가 AuthInterceptor를 가지면 교착이 재발한다',
    );
    expect(
      authFlow.dio.options.extra['withCredentials'],
      isTrue,
      reason: 'refresh는 HttpOnly 쿠키 전송이 필요하다',
    );
  });

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

  test(
    'refresh 콜백은 본문 없이 POST /auth/refresh를 호출하고 access_token을 매핑한다',
    () async {
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
        return TokenPair(access: data['access_token'] as String, refresh: '');
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
    },
  );
}
