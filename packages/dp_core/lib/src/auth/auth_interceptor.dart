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
  final Future<TokenPair> Function(String refreshToken) refresh;
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

    final refreshToken = await store.readRefresh();
    if (refreshToken == null) {
      handler.next(err);
      return;
    }
    try {
      final pair = await refresh(refreshToken);
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
