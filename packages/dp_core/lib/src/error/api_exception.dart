import 'package:dio/dio.dart';

import 'api_error_code.dart';

/// 앱 전역 단일 예외. dio 예외를 도메인 의미로 매핑(스펙 §3·DD4).
class ApiException implements Exception {
  const ApiException({
    required this.code,
    required this.message,
    this.traceId,
    this.status,
    this.retryAfterSeconds,
  });

  final ApiErrorCode code;
  final String message;
  final String? traceId;
  final int? status;
  final int? retryAfterSeconds;

  bool get isKillSwitch => code == ApiErrorCode.aiKillSwitchActive;
  bool get isQuota => code == ApiErrorCode.quotaExceeded;
  bool get isMentorBusy => code == ApiErrorCode.mentorBusy;
  bool get isOnboardingIncomplete => code == ApiErrorCode.onboardingIncomplete;

  factory ApiException.fromDio(DioException e) {
    // 네트워크/타임아웃류
    const networkTypes = {
      DioExceptionType.connectionTimeout,
      DioExceptionType.sendTimeout,
      DioExceptionType.receiveTimeout,
      DioExceptionType.connectionError,
    };
    if (networkTypes.contains(e.type)) {
      return ApiException(
        code: ApiErrorCode.network,
        message: '네트워크 연결을 확인해 주세요.',
      );
    }

    final res = e.response;
    final body = res?.data;
    final retryAfter = res?.headers.value('retry-after');
    return ApiException.fromEnvelope(
      body is Map ? body.cast<String, dynamic>() : const {},
      status: res?.statusCode,
      retryAfterSeconds: retryAfter == null ? null : int.tryParse(retryAfter),
    );
  }

  /// 중첩 §3.4 envelope Map → ApiException. HTTP(fromDio)와 SSE(event:error) 공용.
  factory ApiException.fromEnvelope(
    Map<String, dynamic> body, {
    int? status,
    int? retryAfterSeconds,
  }) {
    final err = (body['error'] is Map)
        ? (body['error'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    return ApiException(
      code: ApiErrorCode.fromWire(err['code'] as String?),
      message: (err['message'] as String?) ?? '알 수 없는 오류가 발생했습니다.',
      traceId: err['trace_id'] as String?,
      status: status,
      retryAfterSeconds: retryAfterSeconds,
    );
  }

  @override
  String toString() =>
      'ApiException($code, $status, "$message", trace=$traceId)';
}
