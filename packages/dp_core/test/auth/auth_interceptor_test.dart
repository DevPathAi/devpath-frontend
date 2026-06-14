import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dp_core/src/auth/auth_interceptor.dart';
import 'package:dp_core/src/auth/token_store.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class _MockRetrier extends Mock {
  Future<Response<dynamic>> call(RequestOptions options);
}

/// access=='Bearer NEW'면 200, 아니면 401 반환하는 최소 어댑터.
class _AuthFlowAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? rs,
      Future? cancelFuture) async {
    final auth = options.headers['Authorization'];
    if (auth == 'Bearer NEW') {
      return ResponseBody.fromString(
        jsonEncode({'ok': true}),
        200,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
      );
    }
    return ResponseBody.fromString(
      jsonEncode({'error': {'code': 'UNAUTHORIZED', 'message': '401'}}),
      401,
      headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
    );
  }
  @override
  void close({bool force = false}) {}
}

void main() {
  setUpAll(() => registerFallbackValue(RequestOptions(path: '/')));

  test('onRequest는 access 토큰을 Bearer로 주입한다', () async {
    final store = InMemoryTokenStore()..save(access: 'AAA', refresh: 'RRR');
    final interceptor = AuthInterceptor(
      store: store,
      refresh: (_) async => const TokenPair(access: 'new', refresh: 'newR'),
      retry: (_) async => Response(requestOptions: RequestOptions(path: '/')),
    );
    final opts = RequestOptions(path: '/users/me');
    final handler = RequestInterceptorHandler();
    await interceptor.onRequest(opts, handler);
    expect(opts.headers['Authorization'], 'Bearer AAA');
  });

  test('401이면 refresh 후 새 토큰으로 재시도한다', () async {
    final store = InMemoryTokenStore()..save(access: 'old', refresh: 'RRR');
    final retrier = _MockRetrier();
    when(() => retrier.call(any())).thenAnswer((_) async => Response(
        requestOptions: RequestOptions(path: '/users/me'),
        statusCode: 200,
        data: {'ok': true}));

    final interceptor = AuthInterceptor(
      store: store,
      refresh: (r) async {
        expect(r, 'RRR');
        return const TokenPair(access: 'NEW', refresh: 'NEWR');
      },
      retry: retrier.call,
    );

    final req = RequestOptions(path: '/users/me');
    final err = DioException(
      requestOptions: req,
      response: Response(requestOptions: req, statusCode: 401),
      type: DioExceptionType.badResponse,
    );
    final handler = ErrorInterceptorHandler();
    await interceptor.onError(err, handler);

    expect(await store.readAccess(), 'NEW'); // 갱신됨
    final captured =
        verify(() => retrier.call(captureAny())).captured.single as RequestOptions;
    expect(captured.headers['Authorization'], 'Bearer NEW'); // 새 토큰으로 재시도
  });

  test('refresh 실패 시 토큰을 비운다', () async {
    final store = InMemoryTokenStore()..save(access: 'old', refresh: 'RRR');
    final interceptor = AuthInterceptor(
      store: store,
      refresh: (_) async => throw StateError('refresh failed'),
      retry: (_) async => Response(requestOptions: RequestOptions(path: '/')),
    );
    final req = RequestOptions(path: '/users/me');
    final err = DioException(
      requestOptions: req,
      response: Response(requestOptions: req, statusCode: 401),
      type: DioExceptionType.badResponse,
    );
    // onError를 파이프라인 밖에서 직접 호출하므로, handler.next(err)가 완료하는
    // completer 에러를 구독할 곳이 없어 존으로 누출된다(실 파이프라인에선 Dio가
    // 소비). 테스트 한정 아티팩트이므로 runZonedGuarded로 격리한다.
    await runZonedGuarded(
      () => interceptor.onError(err, ErrorInterceptorHandler()),
      (_, _) {},
    );
    expect(await store.readAccess(), isNull);
  });

  test('동시 401 N건이 단일 refresh로 직렬화된다(큐잉)', () async {
    var refreshCalls = 0;
    final store = InMemoryTokenStore()..save(access: 'old', refresh: 'RRR');

    final adapter = _AuthFlowAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
      ..httpClientAdapter = adapter;
    // 재시도는 큐를 재진입하지 않도록 별도 dio(동일 어댑터, 인터셉터 없음)로 수행 — 교착 방지.
    final retryDio = Dio(BaseOptions(baseUrl: 'https://api.test'))
      ..httpClientAdapter = adapter;

    dio.interceptors.add(AuthInterceptor(
      store: store,
      refresh: (_) async {
        refreshCalls++;
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return const TokenPair(access: 'NEW', refresh: 'NEWR');
      },
      retry: (req) => retryDio.fetch(req),
    ));

    // 동시 3건 발사.
    final results = await Future.wait([
      dio.get('/a'), dio.get('/b'), dio.get('/c'),
    ]);

    expect(refreshCalls, 1, reason: '동시 401이어도 refresh는 1회');
    expect(results.every((r) => r.statusCode == 200), isTrue);
  });
}
