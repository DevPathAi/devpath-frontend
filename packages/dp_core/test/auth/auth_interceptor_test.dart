import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dp_core/src/auth/auth_interceptor.dart';
import 'package:dp_core/src/auth/token_store.dart';
import 'package:dp_core/src/error/api_error_code.dart';
import 'package:dp_core/src/error/api_exception.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class _MockRetrier extends Mock {
  Future<Response<dynamic>> call(RequestOptions options);
}

class _InspectableErrorHandler extends ErrorInterceptorHandler {
  bool advanced = false;
  bool resolved = false;
  DioException? advancedError;

  Future<void> consume() async {
    try {
      await future;
    } on Object {
      // `next` completes the handler future with the original error state.
    }
  }

  @override
  void next(DioException error) {
    advanced = true;
    advancedError = error;
    super.next(error);
  }

  @override
  void resolve(Response<dynamic> response) {
    resolved = true;
    super.resolve(response);
  }
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

class _LatchSaveTokenStore implements TokenStore {
  _LatchSaveTokenStore({required String access, required String refresh})
    : _access = access,
      _refresh = refresh;

  String? _access;
  String? _refresh;
  final refreshSaveStarted = Completer<void>();
  final _releaseRefreshSave = Completer<void>();

  @override
  Future<String?> readAccess() async => _access;

  @override
  Future<String?> readRefresh() async => _refresh;

  @override
  Future<void> save({required String access, required String refresh}) async {
    if (access == 'A-refreshed') {
      if (!refreshSaveStarted.isCompleted) refreshSaveStarted.complete();
      await _releaseRefreshSave.future;
    }
    _access = access;
    _refresh = refresh;
  }

  void releaseRefreshSave() => _releaseRefreshSave.complete();

  @override
  Future<void> clear() async {
    _access = null;
    _refresh = null;
  }
}

class _CredentialMutationCoordinator {
  Future<void> _tail = Future<void>.value();

  Future<T> run<T>(Future<T> Function() mutation) {
    final operation = _tail.then((_) => mutation());
    _tail = operation.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return operation;
  }
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

    // 실제 파이프라인처럼 요청은 당시의 현재 토큰(old)을 사용했다 — 그래야
    // rotation-guard(현재 토큰과 동일)를 지나 refresh 경로로 진입한다.
    final req = RequestOptions(path: '/users/me')
      ..headers['Authorization'] = 'Bearer old';
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

  test('authoritative refresh rejection clears tokens', () async {
    final store = InMemoryTokenStore()..save(access: 'old', refresh: 'RRR');
    final interceptor = AuthInterceptor(
      store: store,
      refresh: (_) async => null,
      retry: (_) async => Response(requestOptions: RequestOptions(path: '/')),
    );
    // 요청은 당시의 현재 토큰(old)을 사용 — refresh 경로 진입 조건(가드 통과 아님).
    final req = RequestOptions(path: '/users/me')
      ..headers['Authorization'] = 'Bearer old';
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

  for (final status in [401, 403]) {
    test('refresh HTTP $status clears tokens', () async {
      final store = InMemoryTokenStore()..save(access: 'old', refresh: 'RRR');
      final interceptor = AuthInterceptor(
        store: store,
        refresh: (_) async => throw ApiException(
          code: status == 401
              ? ApiErrorCode.unauthorized
              : ApiErrorCode.forbidden,
          message: 'refresh rejected',
          status: status,
        ),
        retry: (_) async => Response(requestOptions: RequestOptions(path: '/')),
      );
      final request = RequestOptions(path: '/resource')
        ..headers['Authorization'] = 'Bearer old';
      final error = DioException(
        requestOptions: request,
        response: Response(requestOptions: request, statusCode: 401),
        type: DioExceptionType.badResponse,
      );
      final handler = _InspectableErrorHandler();
      final consumed = handler.consume();

      await interceptor.onError(error, handler);
      await consumed;

      expect(await store.readAccess(), isNull);
      expect(await store.readRefresh(), isNull);
    });
  }

  test('refresh transport failure retains the existing credential', () async {
    final store = InMemoryTokenStore()..save(access: 'old', refresh: 'RRR');
    final interceptor = AuthInterceptor(
      store: store,
      refresh: (_) async => throw DioException(
        requestOptions: RequestOptions(path: '/auth/refresh'),
        type: DioExceptionType.connectionError,
      ),
      retry: (_) async => Response(requestOptions: RequestOptions(path: '/')),
    );
    final request = RequestOptions(path: '/resource')
      ..headers['Authorization'] = 'Bearer old';
    final error = DioException(
      requestOptions: request,
      response: Response(requestOptions: request, statusCode: 401),
      type: DioExceptionType.badResponse,
    );
    final handler = _InspectableErrorHandler();
    final consumed = handler.consume();

    await interceptor.onError(error, handler);
    await consumed;

    expect(await store.readAccess(), 'old');
    expect(await store.readRefresh(), 'RRR');
    expect(handler.advanced, isTrue);
  });

  test('resource retry failure retains the refreshed credential', () async {
    final store = InMemoryTokenStore()..save(access: 'old', refresh: 'RRR');
    final interceptor = AuthInterceptor(
      store: store,
      refresh: (_) async =>
          const TokenPair(access: 'NEW', refresh: 'NEW-REFRESH'),
      retry: (request) async => throw DioException(
        requestOptions: request,
        type: DioExceptionType.connectionError,
      ),
    );
    final request = RequestOptions(path: '/resource')
      ..headers['Authorization'] = 'Bearer old';
    final error = DioException(
      requestOptions: request,
      response: Response(requestOptions: request, statusCode: 401),
      type: DioExceptionType.badResponse,
    );
    final handler = _InspectableErrorHandler();
    final consumed = handler.consume();

    await interceptor.onError(error, handler);
    await consumed;

    expect(await store.readAccess(), 'NEW');
    expect(await store.readRefresh(), 'NEW-REFRESH');
    expect(handler.advanced, isTrue);
    expect(handler.advancedError?.type, DioExceptionType.connectionError);
  });

  for (final branch in ['rotation', 'refreshed']) {
    for (final normalized in [false, true]) {
      test(
        '$branch retry 401 ${normalized ? 'ApiException' : 'DioException'} '
        'clears the captured credential and forwards retry rejection',
        () async {
          final store = InMemoryTokenStore()
            ..save(
              access: branch == 'rotation' ? 'rotated' : 'old',
              refresh: 'refresh',
            );
          var refreshCalls = 0;
          var terminalSignals = 0;
          final interceptor = AuthInterceptor(
            store: store,
            onSessionInvalidated: (_) async => terminalSignals += 1,
            refresh: (_) async {
              refreshCalls += 1;
              return const TokenPair(access: 'NEW', refresh: 'NEW-REFRESH');
            },
            retry: (request) async => throw _retryFailure(
              request,
              status: 401,
              normalized: normalized,
            ),
          );
          final request = RequestOptions(path: '/resource')
            ..headers['Authorization'] = 'Bearer old';
          final error = DioException(
            requestOptions: request,
            response: Response(requestOptions: request, statusCode: 401),
            type: DioExceptionType.badResponse,
          );
          final handler = _InspectableErrorHandler();
          final consumed = handler.consume();

          await interceptor.onError(error, handler);
          await consumed;

          expect(await store.readAccess(), isNull);
          expect(await store.readRefresh(), isNull);
          expect(refreshCalls, branch == 'rotation' ? 0 : 1);
          expect(terminalSignals, 1);
          expect(_errorStatus(handler.advancedError), 401);
        },
      );
    }

    for (final normalized in [false, true]) {
      test('$branch retry 403 ${normalized ? 'ApiException' : 'DioException'} '
          'retains credential and forwards resource rejection', () async {
        final store = InMemoryTokenStore()
          ..save(
            access: branch == 'rotation' ? 'rotated' : 'old',
            refresh: 'refresh',
          );
        var terminalSignals = 0;
        final interceptor = AuthInterceptor(
          store: store,
          onSessionInvalidated: (_) async => terminalSignals += 1,
          refresh: (_) async =>
              const TokenPair(access: 'NEW', refresh: 'NEW-REFRESH'),
          retry: (request) async =>
              throw _retryFailure(request, status: 403, normalized: normalized),
        );
        final request = RequestOptions(path: '/resource')
          ..headers['Authorization'] = 'Bearer old';
        final error = DioException(
          requestOptions: request,
          response: Response(requestOptions: request, statusCode: 401),
          type: DioExceptionType.badResponse,
        );
        final handler = _InspectableErrorHandler();
        final consumed = handler.consume();

        await interceptor.onError(error, handler);
        await consumed;

        expect(
          await store.readAccess(),
          branch == 'rotation' ? 'rotated' : 'NEW',
        );
        expect(terminalSignals, 0);
        expect(_errorStatus(handler.advancedError), 403);
      });
    }
  }

  for (final branch in ['rotation', 'refreshed']) {
    for (final status in <int?>[null, 408, 425, 429, 500]) {
      test(
        '$branch retry transient ${status ?? 'connection'} retains tokens',
        () async {
          final store = InMemoryTokenStore()
            ..save(
              access: branch == 'rotation' ? 'rotated' : 'old',
              refresh: 'refresh',
            );
          var terminalSignals = 0;
          final interceptor = AuthInterceptor(
            store: store,
            onSessionInvalidated: (_) async => terminalSignals += 1,
            refresh: (_) async =>
                const TokenPair(access: 'NEW', refresh: 'NEW-REFRESH'),
            retry: (request) async => throw DioException(
              requestOptions: request,
              response: status == null
                  ? null
                  : Response(requestOptions: request, statusCode: status),
              type: status == null
                  ? DioExceptionType.connectionError
                  : DioExceptionType.badResponse,
            ),
          );
          final request = RequestOptions(path: '/resource')
            ..headers['Authorization'] = 'Bearer old';
          final error = DioException(
            requestOptions: request,
            response: Response(requestOptions: request, statusCode: 401),
            type: DioExceptionType.badResponse,
          );
          final handler = _InspectableErrorHandler();
          final consumed = handler.consume();

          await interceptor.onError(error, handler);
          await consumed;

          expect(
            await store.readAccess(),
            branch == 'rotation' ? 'rotated' : 'NEW',
          );
          expect(terminalSignals, 0);
          expect(handler.advancedError?.response?.statusCode, status);
          if (status == null) {
            expect(
              handler.advancedError?.type,
              DioExceptionType.connectionError,
            );
          }
        },
      );
    }
  }

  test(
    'ordinary initial 403 neither refreshes nor clears credentials',
    () async {
      final store = InMemoryTokenStore()
        ..save(access: 'access', refresh: 'refresh');
      var refreshCalls = 0;
      var retryCalls = 0;
      var terminalSignals = 0;
      final interceptor = AuthInterceptor(
        store: store,
        onSessionInvalidated: (_) async => terminalSignals += 1,
        refresh: (_) async {
          refreshCalls += 1;
          return null;
        },
        retry: (request) async {
          retryCalls += 1;
          return Response(requestOptions: request);
        },
      );
      final request = RequestOptions(path: '/forbidden');
      final error = DioException(
        requestOptions: request,
        response: Response(requestOptions: request, statusCode: 403),
        type: DioExceptionType.badResponse,
      );
      final handler = _InspectableErrorHandler();
      final consumed = handler.consume();

      await interceptor.onError(error, handler);
      await consumed;

      expect(await store.readAccess(), 'access');
      expect(refreshCalls, 0);
      expect(retryCalls, 0);
      expect(terminalSignals, 0);
      expect(handler.advanced, isTrue);
    },
  );

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

    // 요청은 당시의 현재 토큰(old)을 사용 — refresh 경로 진입 조건(가드 통과 아님).
    final req = RequestOptions(path: '/users/me')
      ..headers['Authorization'] = 'Bearer old';
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

  test('무토큰 요청 401 후 현재 토큰이 있으면 refresh 없이 재시도한다', () async {
    // 부팅 직후 대시보드 fetch처럼 Authorization 없이 발사된 요청이 401을 받았고,
    // 그 사이 다른 경로(부트스트랩)가 access를 확보했다면 refresh를 추가 발사하지 않고
    // 현재 토큰으로 재시도해야 한다(불필요한 회전 방지).
    var refreshCalls = 0;
    final store = InMemoryTokenStore()..save(access: 'CUR', refresh: 'R');
    final retrier = _MockRetrier();
    when(() => retrier.call(any())).thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(path: '/dashboard/me'),
        statusCode: 200,
        data: {'ok': true},
      ),
    );

    final interceptor = AuthInterceptor(
      store: store,
      refresh: (_) async {
        refreshCalls++;
        return const TokenPair(access: 'NEW', refresh: '');
      },
      retry: retrier.call,
    );

    final req = RequestOptions(path: '/dashboard/me'); // 무토큰 발사(헤더 없음)
    final err = DioException(
      requestOptions: req,
      response: Response(requestOptions: req, statusCode: 401),
      type: DioExceptionType.badResponse,
    );
    await interceptor.onError(err, ErrorInterceptorHandler());

    expect(refreshCalls, 0, reason: '이미 확보된 토큰이 있으면 refresh 불필요');
    final captured =
        verify(() => retrier.call(captureAny())).captured.single
            as RequestOptions;
    expect(captured.headers['Authorization'], 'Bearer CUR');
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

  test(
    'old account 401 is never retried with the replacement account token',
    () async {
      var epoch = 1;
      var refreshCalls = 0;
      final store = InMemoryTokenStore()
        ..save(access: 'A-access', refresh: 'A-refresh');
      final retrier = _MockRetrier();
      final interceptor = AuthInterceptor(
        store: store,
        sessionEpoch: () async => epoch,
        refresh: (_) async {
          refreshCalls += 1;
          return const TokenPair(access: 'unexpected', refresh: 'unexpected');
        },
        retry: retrier.call,
      );
      final request = RequestOptions(
        path: '/community/questions',
        method: 'POST',
      );
      await interceptor.onRequest(request, RequestInterceptorHandler());
      expect(request.headers['Authorization'], 'Bearer A-access');

      epoch = 2;
      await store.save(access: 'B-access', refresh: 'B-refresh');
      final error = DioException(
        requestOptions: request,
        response: Response(requestOptions: request, statusCode: 401),
        type: DioExceptionType.badResponse,
      );
      await runZonedGuarded(
        () => interceptor.onError(error, ErrorInterceptorHandler()),
        (_, _) {},
      );

      verifyNever(() => retrier.call(any()));
      expect(refreshCalls, 0);
      expect(await store.readAccess(), 'B-access');
    },
  );

  test('late refresh save cannot overwrite a replacement credential', () async {
    var epoch = 1;
    var retryCalls = 0;
    final store = _LatchSaveTokenStore(
      access: 'A-access',
      refresh: 'A-refresh',
    );
    final coordinator = _CredentialMutationCoordinator();
    final interceptor = AuthInterceptor(
      store: store,
      sessionEpoch: () async => epoch,
      credentialMutation: coordinator.run,
      refresh: (_) async =>
          const TokenPair(access: 'A-refreshed', refresh: 'A-refresh-rotated'),
      retry: (request) async {
        retryCalls += 1;
        return Response(requestOptions: request, statusCode: 200);
      },
    );
    final request = RequestOptions(
      path: '/contents/1/progress',
      method: 'POST',
    );
    await interceptor.onRequest(request, RequestInterceptorHandler());
    final error = DioException(
      requestOptions: request,
      response: Response(requestOptions: request, statusCode: 401),
      type: DioExceptionType.badResponse,
    );
    final errorDone = runZonedGuarded<Future<void>>(
      () => interceptor.onError(error, ErrorInterceptorHandler()),
      (_, _) {},
    );

    await store.refreshSaveStarted.future;
    epoch = 2;
    final replacement = coordinator.run(
      () => store.save(access: 'B-access', refresh: 'B-refresh'),
    );
    await Future<void>.delayed(Duration.zero);
    store.releaseRefreshSave();
    await errorDone;
    await replacement;

    expect(await store.readAccess(), 'B-access');
    expect(await store.readRefresh(), 'B-refresh');
    expect(retryCalls, 0);
  });

  test(
    'post-clear terminal signal is dropped after a same-owner session ABA',
    () async {
      var epoch = 1;
      var terminalSignals = 0;
      final clearCompleted = Completer<void>();
      final releaseMutation = Completer<void>();
      final store = InMemoryTokenStore()
        ..save(access: 'A-access', refresh: 'A-refresh');
      Future<T> delayedMutation<T>(Future<T> Function() mutation) async {
        final result = await mutation();
        if (!clearCompleted.isCompleted) clearCompleted.complete();
        await releaseMutation.future;
        return result;
      }

      final interceptor = AuthInterceptor(
        store: store,
        sessionEpoch: () async => epoch,
        credentialMutation: delayedMutation,
        onSessionInvalidated: (_) async => terminalSignals += 1,
        refresh: (_) async => null,
        retry: (request) async => Response(requestOptions: request),
      );
      final request = RequestOptions(path: '/contents/1');
      await interceptor.onRequest(request, RequestInterceptorHandler());
      final error = DioException(
        requestOptions: request,
        response: Response(requestOptions: request, statusCode: 401),
        type: DioExceptionType.badResponse,
      );
      final handler = _InspectableErrorHandler();
      final consumed = handler.consume();
      final handling = interceptor.onError(error, handler);

      await clearCompleted.future;
      epoch = 2;
      await store.save(access: 'A-new-session', refresh: 'A-new-refresh');
      releaseMutation.complete();
      await handling;
      await consumed;

      expect(await store.readAccess(), 'A-new-session');
      expect(await store.readRefresh(), 'A-new-refresh');
      expect(terminalSignals, 0);
    },
  );

  test('blocked retry never holds the credential mutation boundary', () async {
    var epoch = 1;
    final retryStarted = Completer<void>();
    final releaseRetry = Completer<void>();
    final store = InMemoryTokenStore()
      ..save(access: 'A-access', refresh: 'A-refresh');
    final coordinator = _CredentialMutationCoordinator();
    final interceptor = AuthInterceptor(
      store: store,
      sessionEpoch: () async => epoch,
      credentialMutation: coordinator.run,
      refresh: (_) async =>
          const TokenPair(access: 'A-refreshed', refresh: 'A-refresh-2'),
      retry: (request) async {
        retryStarted.complete();
        await releaseRetry.future;
        return Response(requestOptions: request, statusCode: 200);
      },
    );
    final request = RequestOptions(path: '/mutation', method: 'POST');
    await interceptor.onRequest(request, RequestInterceptorHandler());
    final error = DioException(
      requestOptions: request,
      response: Response(requestOptions: request, statusCode: 401),
      type: DioExceptionType.badResponse,
    );
    final handler = _InspectableErrorHandler();
    final consumed = handler.consume();
    final errorDone = interceptor.onError(error, handler);

    await retryStarted.future;
    epoch = 2;
    final replacement = coordinator.run(
      () => store.save(access: 'B-access', refresh: 'B-refresh'),
    );
    var replacementCompletedPromptly = true;
    try {
      await replacement.timeout(const Duration(milliseconds: 100));
    } on TimeoutException {
      replacementCompletedPromptly = false;
    } finally {
      releaseRetry.complete();
      await errorDone;
      await replacement;
    }

    expect(replacementCompletedPromptly, isTrue);
    await consumed;
    expect(handler.advanced, isTrue);
    expect(handler.resolved, isFalse);
    expect(await store.readAccess(), 'B-access');
    expect(await store.readRefresh(), 'B-refresh');
  });

  test('same account token rotation still retries exactly once', () async {
    var epoch = 7;
    var refreshCalls = 0;
    final store = InMemoryTokenStore()
      ..save(access: 'old', refresh: 'same-owner-refresh');
    final retrier = _MockRetrier();
    when(() => retrier.call(any())).thenAnswer(
      (invocation) async => Response(
        requestOptions: invocation.positionalArguments.single as RequestOptions,
        statusCode: 200,
      ),
    );
    final interceptor = AuthInterceptor(
      store: store,
      sessionEpoch: () async => epoch,
      refresh: (_) async {
        refreshCalls += 1;
        return const TokenPair(access: 'unexpected', refresh: 'unexpected');
      },
      retry: retrier.call,
    );
    final request = RequestOptions(
      path: '/contents/1/progress',
      method: 'POST',
    );
    await interceptor.onRequest(request, RequestInterceptorHandler());
    await store.save(access: 'rotated', refresh: 'same-owner-refresh');

    final error = DioException(
      requestOptions: request,
      response: Response(requestOptions: request, statusCode: 401),
      type: DioExceptionType.badResponse,
    );
    await interceptor.onError(error, ErrorInterceptorHandler());

    expect(epoch, 7);
    expect(refreshCalls, 0);
    final retried =
        verify(() => retrier.call(captureAny())).captured.single
            as RequestOptions;
    expect(retried.headers['Authorization'], 'Bearer rotated');
  });
}

Object _retryFailure(
  RequestOptions request, {
  required int status,
  required bool normalized,
}) {
  if (normalized) {
    return ApiException(
      code: status == 401 ? ApiErrorCode.unauthorized : ApiErrorCode.forbidden,
      message: 'retry rejected',
      status: status,
    );
  }
  return DioException(
    requestOptions: request,
    response: Response(requestOptions: request, statusCode: status),
    type: DioExceptionType.badResponse,
  );
}

int? _errorStatus(DioException? error) {
  final normalized = error?.error;
  return error?.response?.statusCode ??
      (normalized is ApiException ? normalized.status : null);
}
