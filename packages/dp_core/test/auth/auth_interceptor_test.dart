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

/// 웹 HttpOnly 쿠키 시나리오: access만 메모리, refresh는 항상 null(쿠키에 있음).
class _CookieOnlyTokenStore implements TokenStore {
  // ignore: prefer_initializing_formals
  _CookieOnlyTokenStore({required String access}) : _access = access;
  String? _access;

  @override
  Future<String?> readAccess() async => _access;

  @override
  Future<String?> readRefresh() async => null; // 쿠키라 JS에서 읽을 수 없음

  @override
  Future<void> save({required String access, required String refresh}) async {
    _access = access;
    // refresh는 쿠키로 관리되므로 저장 안 함
  }

  @override
  Future<void> clear() async => _access = null;
}

/// access=='Bearer NEW'면 200, 아니면 401 반환하는 최소 어댑터.
class _AuthFlowAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? rs,
    Future? cancelFuture,
  ) async {
    final auth = options.headers['Authorization'];
    if (auth == 'Bearer NEW') {
      return ResponseBody.fromString(
        jsonEncode({'ok': true}),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
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
    when(() => retrier.call(any())).thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(path: '/users/me'),
        statusCode: 200,
        data: {'ok': true},
      ),
    );

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
        verify(() => retrier.call(captureAny())).captured.single
            as RequestOptions;
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

  test('readRefresh==null이어도 refresh(null)을 시도하여 재시도한다(쿠키 기반)', () async {
    // 웹 HttpOnly 쿠키 시나리오: store에 refresh 토큰 없음(null), 서버는 쿠키로 인식.
    // InMemoryTokenStore는 save 시 refresh가 항상 저장되므로,
    // readRefresh()가 null을 반환하는 쿠키 전용 store를 인라인으로 구현한다.
    final store = _CookieOnlyTokenStore(access: 'old');

    final retrier = _MockRetrier();
    when(() => retrier.call(any())).thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(path: '/users/me'),
        statusCode: 200,
        data: {'ok': true},
      ),
    );

    String? capturedRefreshArg;
    final interceptor = AuthInterceptor(
      store: store,
      refresh: (r) async {
        capturedRefreshArg = r;
        return const TokenPair(access: 'COOKIE_NEW', refresh: '');
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

    // refresh(null)이 호출되어야 한다(쿠키 기반이므로 인자는 null).
    expect(capturedRefreshArg, isNull, reason: 'readRefresh==null이므로 null로 호출');
    // 새 access 토큰이 저장되어야 한다.
    expect(await store.readAccess(), 'COOKIE_NEW');
    // retry가 새 토큰 헤더로 호출되어야 한다.
    final captured =
        verify(() => retrier.call(captureAny())).captured.single
            as RequestOptions;
    expect(captured.headers['Authorization'], 'Bearer COOKIE_NEW');
  });

  test('쿠키 store + 동시 401 N건 → refresh 1회·모든 요청 재시도 성공', () async {
    // rotation-guard가 _CookieOnlyTokenStore 조합에서도 동작함을 검증한다.
    // readRefresh()==null 이므로 refresh 콜백에는 null이 전달되며,
    // 첫 요청이 refresh를 완료하면 나머지는 rotation-guard 경로로 처리된다.
    var refreshCalls = 0;
    final store = _CookieOnlyTokenStore(access: 'old');

    final adapter = _AuthFlowAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
      ..httpClientAdapter = adapter;
    final retryDio = Dio(BaseOptions(baseUrl: 'https://api.test'))
      ..httpClientAdapter = adapter;

    dio.interceptors.add(
      AuthInterceptor(
        store: store,
        refresh: (r) async {
          expect(r, isNull, reason: '쿠키 기반이므로 refreshToken 인자는 null이어야 함');
          refreshCalls++;
          await Future<void>.delayed(const Duration(milliseconds: 10));
          // 쿠키 기반: refresh는 ''(쿠키가 실 토큰 보유)
          return const TokenPair(access: 'NEW', refresh: '');
        },
        retry: (req) => retryDio.fetch(req),
      ),
    );

    final results = await Future.wait([
      dio.get('/a'),
      dio.get('/b'),
      dio.get('/c'),
    ]);

    expect(refreshCalls, 1, reason: '쿠키 store + 동시 401이어도 refresh는 1회');
    expect(results.every((r) => r.statusCode == 200), isTrue);
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

    dio.interceptors.add(
      AuthInterceptor(
        store: store,
        refresh: (_) async {
          refreshCalls++;
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return const TokenPair(access: 'NEW', refresh: 'NEWR');
        },
        retry: (req) => retryDio.fetch(req),
      ),
    );

    // 동시 3건 발사.
    final results = await Future.wait([
      dio.get('/a'),
      dio.get('/b'),
      dio.get('/c'),
    ]);

    expect(refreshCalls, 1, reason: '동시 401이어도 refresh는 1회');
    expect(results.every((r) => r.statusCode == 200), isTrue);
  });
}
