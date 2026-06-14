import 'package:dio/dio.dart';
import 'package:dp_core/src/error/api_error_code.dart';
import 'package:dp_core/src/error/api_exception.dart';
import 'package:test/test.dart';

void main() {
  group('ApiErrorCode.fromWire', () {
    test('알려진 코드를 매핑한다', () {
      expect(
        ApiErrorCode.fromWire('QUOTA_EXCEEDED'),
        ApiErrorCode.quotaExceeded,
      );
      expect(
        ApiErrorCode.fromWire('AI_KILL_SWITCH_ACTIVE'),
        ApiErrorCode.aiKillSwitchActive,
      );
    });
    test('알 수 없는 코드는 unknown으로 방어한다', () {
      expect(ApiErrorCode.fromWire('SOMETHING_NEW'), ApiErrorCode.unknown);
      expect(ApiErrorCode.fromWire(null), ApiErrorCode.unknown);
    });
  });

  group('ApiException.fromDio', () {
    ApiException mapStatus(
      int status,
      Map<String, dynamic> body, {
      Headers? headers,
    }) {
      final req = RequestOptions(path: '/x');
      final e = DioException(
        requestOptions: req,
        response: Response(
          requestOptions: req,
          statusCode: status,
          data: body,
          headers: headers,
        ),
        type: DioExceptionType.badResponse,
      );
      return ApiException.fromDio(e);
    }

    test('공통 에러 포맷을 파싱한다', () {
      final ex = mapStatus(403, {
        'error': {
          'code': 'ONBOARDING_INCOMPLETE',
          'message': '온보딩 필요',
          'trace_id': 't-1',
        },
      });
      expect(ex.code, ApiErrorCode.onboardingIncomplete);
      expect(ex.message, '온보딩 필요');
      expect(ex.traceId, 't-1');
      expect(ex.status, 403);
    });

    test('429는 Retry-After 헤더를 보존한다', () {
      final ex = mapStatus(
        429,
        {
          'error': {'code': 'QUOTA_EXCEEDED', 'message': '한도 초과'},
        },
        headers: Headers.fromMap({
          'retry-after': ['30'],
        }),
      );
      expect(ex.code, ApiErrorCode.quotaExceeded);
      expect(ex.retryAfterSeconds, 30);
    });

    test('연결 타임아웃은 network로 매핑한다', () {
      final e = DioException(
        requestOptions: RequestOptions(path: '/x'),
        type: DioExceptionType.connectionTimeout,
      );
      expect(ApiException.fromDio(e).code, ApiErrorCode.network);
    });
  });
}
