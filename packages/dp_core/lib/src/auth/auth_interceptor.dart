import 'package:dio/dio.dart';

import 'token_store.dart';

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
  });

  final TokenStore store;

  /// refresh 콜백 시그니처: `String? refreshToken` → 웹 쿠키 기반은 인자 무시·쿠키 사용,
  /// 모바일/일반은 전달받은 토큰을 사용. null 반환 시 인증 실패(store.clear + 에러 전파).
  final Future<TokenPair?> Function(String? refreshToken) refresh;
  final Future<Response<dynamic>> Function(RequestOptions options) retry;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final access = await store.readAccess();
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

    final currentAccess = await store.readAccess();
    final usedAuth = err.requestOptions.headers['Authorization'] as String?;

    // 다른 요청이 이미 토큰을 교체했다면(요청이 쓴 토큰 != 현재 토큰) refresh 없이 재시도.
    if (usedAuth != null &&
        currentAccess != null &&
        usedAuth != 'Bearer $currentAccess') {
      try {
        final req = err.requestOptions
          ..headers['Authorization'] = 'Bearer $currentAccess';
        final res = await retry(req);
        handler.resolve(res);
      } catch (_) {
        handler.next(err);
      }
      return;
    }

    // 웹: refresh 토큰이 HttpOnly 쿠키라 JS에서 읽을 수 없어 null일 수 있음.
    // null이어도 refresh(null)을 호출해 쿠키 기반 갱신을 시도한다.
    final refreshToken = await store.readRefresh();
    try {
      final pair = await refresh(refreshToken); // 쿠키 기반이면 인자 무시
      if (pair == null) {
        // refresh 콜백이 null 반환 → 갱신 불가(쿠키 만료 등)
        await store.clear();
        handler.next(err);
        return;
      }
      // 쿠키 기반 시 pair.refresh==''(실 refresh 토큰은 HttpOnly 쿠키가 보유).
      // TokenStore.save는 refresh=''를 저장하지만 웹 구현체는 이를 무시한다
      // (readRefresh()는 항상 null을 반환해 쿠키 경로를 유지한다).
      await store.save(access: pair.access, refresh: pair.refresh);
      final req = err.requestOptions
        ..headers['Authorization'] = 'Bearer ${pair.access}';
      final res = await retry(req);
      handler.resolve(res); // 재시도 성공 → 원 요청을 해당 응답으로 해결
    } catch (_) {
      await store.clear();
      handler.next(err); // 갱신 실패 → 원 에러 전파(상위에서 로그인 유도)
    }
  }
}
