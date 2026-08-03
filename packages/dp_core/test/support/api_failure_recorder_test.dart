import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dp_core/dp_core.dart';
import 'package:test/test.dart';

/// 고정 상태코드·본문을 돌려주는 어댑터.
class _FixedAdapter implements HttpClientAdapter {
  _FixedAdapter(this.status, this.body);
  final int status;
  final Object body;
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    calls++;
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// add 가 항상 던지는 로그 — recorder 가 예외를 삼키는지 검증한다.
class _ThrowingLog implements ApiFailureLog {
  @override
  int get capacity => 10;

  @override
  void add(ApiFailureEntry entry) => throw StateError('boom');

  @override
  void clear() {}

  @override
  int get length => 0;

  @override
  List<ApiFailureEntry> get recent => const [];
}

ApiClient _clientWithRecorder(
  ApiFailureLog log, {
  List<Interceptor> before = const [],
  required HttpClientAdapter adapter,
}) {
  final client = ApiClient.create(
    const ApiConfig(baseUrl: 'https://example.test', useMock: false),
    interceptors: before,
  );
  // Auth 뒤 · ErrorNormalizer 앞.
  client.dio.interceptors.insert(
    client.dio.interceptors.length - 1,
    ApiFailureRecorder(log),
  );
  client.dio.httpClientAdapter = adapter;
  return client;
}

void main() {
  group('ApiFailureLog', () {
    test('11건째에 가장 오래된 것이 밀려난다', () {
      final log = ApiFailureLog();
      for (var i = 0; i < 11; i++) {
        log.add(
          ApiFailureEntry(
            method: 'GET',
            path: '/x/$i',
            occurredAt: DateTime.utc(2026, 8, 3, 0, 0, i),
          ),
        );
      }
      expect(log.length, 10);
      // 0 = 가장 최근
      expect(log.recent.first.path, '/x/10');
      expect(log.recent.last.path, '/x/1');
      expect(log.recent.any((e) => e.path == '/x/0'), isFalse);
    });
  });

  group('ApiFailureRecorder', () {
    test('실패를 버퍼에 쌓는다 — 마스킹·쿼리스트링 제거 포함', () async {
      final log = ApiFailureLog();
      final client = _clientWithRecorder(
        log,
        adapter: _FixedAdapter(500, {
          'error': {
            'code': 'INTERNAL_ERROR',
            'message': '문의: hong@example.com',
            'trace_id': 't-1',
          },
        }),
      );

      await expectLater(
        client.post<Map<String, dynamic>>('/learning-paths?draft=1'),
        throwsA(isA<ApiException>()),
      );

      expect(log.length, 1);
      final e = log.recent.first;
      expect(e.method, 'POST');
      expect(e.path, '/learning-paths'); // 쿼리스트링 제거
      expect(e.statusCode, 500);
      expect(e.errorCode, 'INTERNAL_ERROR'); // enum 밖 코드도 원문 보존
      expect(e.traceId, 't-1');
      expect(e.message, '문의: [EMAIL]'); // 기록 시점에 이미 마스킹
    });

    test('refresh 로 복구된 401 은 기록되지 않는다', () async {
      final log = ApiFailureLog();
      final store = InMemoryTokenStore();
      await store.save(access: 'old', refresh: 'r');

      final auth = AuthInterceptor(
        store: store,
        refresh: (_) async => const TokenPair(access: 'new', refresh: 'r'),
        retry: (options) async => Response<dynamic>(
          requestOptions: options,
          statusCode: 200,
          data: const <String, dynamic>{},
        ),
      );

      final client = _clientWithRecorder(
        log,
        before: [auth],
        adapter: _FixedAdapter(401, {
          'error': {'code': 'UNAUTHORIZED', 'message': '만료'},
        }),
      );

      await client.get<Map<String, dynamic>>('/dashboard');

      // Auth 가 handler.resolve 로 체인을 종료하므로 recorder 에 도달하지 않는다.
      expect(log.length, 0);
    });

    test('refresh 가 실패한 401 은 기록된다', () async {
      final log = ApiFailureLog();
      final store = InMemoryTokenStore();
      await store.save(access: 'old', refresh: 'r');

      final auth = AuthInterceptor(
        store: store,
        refresh: (_) async => null, // 갱신 불가
        retry: (options) async => Response<dynamic>(
          requestOptions: options,
          statusCode: 200,
          data: const <String, dynamic>{},
        ),
      );

      final client = _clientWithRecorder(
        log,
        before: [auth],
        adapter: _FixedAdapter(401, {
          'error': {'code': 'UNAUTHORIZED', 'message': '만료'},
        }),
      );

      await expectLater(
        client.get<Map<String, dynamic>>('/dashboard'),
        throwsA(isA<ApiException>()),
      );

      expect(log.length, 1);
      expect(log.recent.first.statusCode, 401);
    });

    test('기록 중 예외가 원래 에러 흐름을 바꾸지 않는다', () async {
      final client = _clientWithRecorder(
        _ThrowingLog(),
        adapter: _FixedAdapter(503, {
          'error': {'code': 'SANDBOX_UNAVAILABLE', 'message': '점검 중'},
        }),
      );

      // recorder 가 삼켜야 하므로, 던져지는 것은 여전히 ApiException 이다.
      await expectLater(
        client.get<Map<String, dynamic>>('/sandbox'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.code,
            'code',
            ApiErrorCode.sandboxUnavailable,
          ),
        ),
      );
    });

    test('★불변식★ 정규화 인터셉터가 체인의 마지막이다', () {
      final client = ApiClient.create(
        const ApiConfig(baseUrl: 'https://example.test', useMock: false),
        interceptors: [
          AuthInterceptor(
            store: InMemoryTokenStore(),
            refresh: (_) async => null,
            retry: (o) async => Response<dynamic>(requestOptions: o),
          ),
        ],
      );
      // ApiClient.create 가 마지막에 추가하는 정규화는 InterceptorsWrapper 다.
      // 이 단언이 깨지면 `insert(length - 1, recorder)` 배선이 조용히 틀려진다.
      expect(client.dio.interceptors.last, isA<InterceptorsWrapper>());

      // dio 는 index 0 에 ImplyContentTypeInterceptor 를 기본 장착한다(실측:
      // [ImplyContentTypeInterceptor, AuthInterceptor, InterceptorsWrapper]).
      // 따라서 "첫 인터셉터가 Auth" 는 성립하지 않는다 — 보호해야 할 불변식은
      // **정규화가 마지막**이라는 것뿐이고, 아래가 그 결과를 직접 확인한다.
      client.dio.interceptors.insert(
        client.dio.interceptors.length - 1,
        ApiFailureRecorder(ApiFailureLog()),
      );
      final chain = client.dio.interceptors;
      expect(chain[chain.length - 2], isA<ApiFailureRecorder>());
      expect(chain.last, isA<InterceptorsWrapper>());
      // Auth 는 recorder 보다 앞이어야 한다(복구된 401 이 기록되지 않는 근거).
      expect(
        chain.indexWhere((i) => i is AuthInterceptor),
        lessThan(chain.indexWhere((i) => i is ApiFailureRecorder)),
      );
    });
  });
}
