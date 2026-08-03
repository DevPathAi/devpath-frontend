import 'package:dio/dio.dart';

import '../error/api_exception.dart';
import 'api_failure_log.dart';
import 'sensitive_text_masker.dart';

/// 최근 API 실패를 링버퍼에 기록하는 인터셉터.
///
/// **배선 위치가 정확도를 좌우한다: `Auth` 뒤 · `ErrorNormalizer` 앞.**
/// - index 0 이면 AuthInterceptor 가 refresh 로 복구하는 일시적 401까지 기록되어,
///   사용자가 겪지도 않은 실패가 제보에 섞인다.
/// - 정규화 뒤면 아무것도 못 본다 — 정규화가 `handler.reject()` 로 체인을 끝낸다.
///
/// **절대 예외를 던지지 않는다.** 진단 기능이 진단 대상을 망가뜨리면 안 된다.
class ApiFailureRecorder extends Interceptor {
  ApiFailureRecorder(this.log, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  static const int _messageMax = 500;

  final ApiFailureLog log;
  final DateTime Function() _clock;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    try {
      log.add(_toEntry(err));
    } catch (_) {
      // 기록 중 어떤 오류가 나도 삼키고 원래 에러를 그대로 통과시킨다.
    }
    handler.next(err);
  }

  ApiFailureEntry _toEntry(DioException err) {
    final req = err.requestOptions;
    final res = err.response;
    // 이 인터셉터는 정규화 **앞**이라 err.error 는 아직 ApiException 이 아니다.
    // message·traceId 는 직접 정규화해 얻는다.
    final normalized = ApiException.fromDio(err);
    // errorCode 는 enum 으로 좁히지 않고 응답 본문의 **원문 문자열**을 읽는다 —
    // 서버가 ApiErrorCode 에 없는 코드(예: INTERNAL_ERROR)도 보내기 때문이다.
    final body = res?.data;
    final errObj = (body is Map && body['error'] is Map)
        ? (body['error'] as Map)
        : const <dynamic, dynamic>{};

    return ApiFailureEntry(
      method: req.method,
      path: _stripQuery(req.path),
      statusCode: res?.statusCode,
      errorCode: errObj['code'] as String?,
      traceId: normalized.traceId,
      message: SensitiveTextMasker.maskAndTruncate(
        normalized.message,
        _messageMax,
      ),
      occurredAt: _clock(),
    );
  }

  static String _stripQuery(String path) {
    final i = path.indexOf('?');
    return i < 0 ? path : path.substring(0, i);
  }
}
