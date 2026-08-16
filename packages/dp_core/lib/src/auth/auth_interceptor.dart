import 'package:dio/dio.dart';

import 'token_store.dart';

typedef AuthCredentialMutationRunner =
    Future<T> Function<T>(Future<T> Function() mutation);

/// 401 시 큐잉 갱신(다중 동시요청을 한 번의 refresh로 직렬화). 참조 샘플 §7.
///
/// QueuedInterceptor가 onError를 직렬화하므로, 첫 요청이 refresh하는 동안
/// 나머지는 대기한다. 깨어난 요청은 토큰이 이미 교체된 것을 감지하면(rotation guard)
/// refresh 없이 새 토큰으로 재시도한다 → refresh는 1회만 발생한다.
class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({
    required this.store,
    required this.refresh,
    required this.retry,
    this.sessionEpoch,
    this.credentialMutation,
  });

  static const _sessionEpochExtra = 'dp_core.auth.session_epoch';

  final TokenStore store;

  /// refresh 콜백 시그니처: `String? refreshToken` → 웹 쿠키 기반은 인자 무시·쿠키 사용,
  /// 모바일/일반은 전달받은 토큰을 사용. null 반환 시 인증 실패(store.clear + 에러 전파).
  final Future<TokenPair?> Function(String? refreshToken) refresh;
  final Future<Response<dynamic>> Function(RequestOptions options) retry;

  /// Optional account/session generation used by native clients to prevent an
  /// old request from being replayed with a replacement account's token.
  /// Web clients may omit it and retain the token-only rotation guard.
  final Future<Object?> Function()? sessionEpoch;

  /// Optional native credential boundary. When supplied, refresh saves,
  /// retries, and failure clears share one serialized mutation tail with
  /// account replacement/logout. Web clients may omit it.
  final AuthCredentialMutationRunner? credentialMutation;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final readEpoch = sessionEpoch;
    if (readEpoch != null && !options.extra.containsKey(_sessionEpochExtra)) {
      options.extra[_sessionEpochExtra] = await readEpoch();
    }
    final access = await store.readAccess();
    if (!await _isSameSession(options)) {
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.cancel,
          error: StateError('authentication session changed before dispatch'),
        ),
      );
      return;
    }
    if (access != null) {
      options.headers['Authorization'] = 'Bearer $access';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode != 401) {
      handler.next(err);
      return;
    }

    if (!await _isSameSession(err.requestOptions)) {
      handler.next(err);
      return;
    }

    final currentAccess = await store.readAccess();
    if (!await _isSameSession(err.requestOptions)) {
      handler.next(err);
      return;
    }
    final usedAuth = err.requestOptions.headers['Authorization'] as String?;

    // 다른 요청/부트스트랩이 이미 유효 토큰을 확보했다면(요청이 쓴 토큰 != 현재 토큰)
    // refresh 없이 현재 토큰으로 재시도한다. 무토큰 발사(usedAuth==null) 요청도 포함 —
    // 부팅 직후 선발사 요청의 401마다 refresh를 추가 발사(불필요한 회전)하지 않기 위함.
    if (currentAccess != null && usedAuth != 'Bearer $currentAccess') {
      if (!await _isSameSession(err.requestOptions)) {
        handler.next(err);
        return;
      }
      try {
        final res = await _mutateCredential<Response<dynamic>?>(() async {
          if (!await _isSameSession(err.requestOptions)) return null;
          final req = err.requestOptions
            ..headers['Authorization'] = 'Bearer $currentAccess';
          final response = await retry(req);
          if (!await _isSameSession(err.requestOptions)) return null;
          return response;
        });
        if (res == null) {
          handler.next(err);
        } else {
          handler.resolve(res);
        }
      } catch (_) {
        handler.next(err);
      }
      return;
    }

    // 웹: refresh 토큰이 HttpOnly 쿠키라 JS에서 읽을 수 없어 null일 수 있음.
    // null이어도 refresh(null)을 호출해 쿠키 기반 갱신을 시도한다.
    final refreshToken = await store.readRefresh();
    if (!await _isSameSession(err.requestOptions)) {
      handler.next(err);
      return;
    }
    try {
      final pair = await refresh(refreshToken); // 쿠키 기반이면 인자 무시
      if (!await _isSameSession(err.requestOptions)) {
        handler.next(err);
        return;
      }
      if (pair == null) {
        // refresh 콜백이 null 반환 → 갱신 불가(쿠키 만료 등)
        await _clearIfSameSession(err.requestOptions);
        handler.next(err);
        return;
      }
      // 쿠키 기반 시 pair.refresh==''(실 refresh 토큰은 HttpOnly 쿠키가 보유).
      // TokenStore.save는 refresh=''를 저장하지만 웹 구현체는 이를 무시한다
      // (readRefresh()는 항상 null을 반환해 쿠키 경로를 유지한다).
      final res = await _mutateCredential<Response<dynamic>?>(() async {
        if (!await _isSameSession(err.requestOptions)) return null;
        await store.save(access: pair.access, refresh: pair.refresh);
        if (!await _isSameSession(err.requestOptions)) return null;
        final req = err.requestOptions
          ..headers['Authorization'] = 'Bearer ${pair.access}';
        final response = await retry(req);
        if (!await _isSameSession(err.requestOptions)) return null;
        return response;
      });
      if (res == null) {
        handler.next(err);
        return;
      }
      handler.resolve(res); // 재시도 성공 → 원 요청을 해당 응답으로 해결
    } catch (_) {
      await _clearIfSameSession(err.requestOptions);
      handler.next(err); // 갱신 실패 → 원 에러 전파(상위에서 로그인 유도)
    }
  }

  Future<void> _clearIfSameSession(RequestOptions options) =>
      _mutateCredential(() async {
        if (await _isSameSession(options)) await store.clear();
      });

  Future<T> _mutateCredential<T>(Future<T> Function() mutation) {
    final runner = credentialMutation;
    return runner == null ? mutation() : runner(mutation);
  }

  Future<bool> _isSameSession(RequestOptions options) async {
    final readEpoch = sessionEpoch;
    if (readEpoch == null) return true;
    if (!options.extra.containsKey(_sessionEpochExtra)) return false;
    return options.extra[_sessionEpochExtra] == await readEpoch();
  }
}
