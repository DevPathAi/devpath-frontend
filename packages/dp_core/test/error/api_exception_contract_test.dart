import 'package:dio/dio.dart';
import 'package:dp_core/src/error/api_error_code.dart';
import 'package:dp_core/src/error/api_exception.dart';
import 'package:test/test.dart';

/// 백엔드 스펙 §3.4 공통 envelope 계약을 프론트 측에서 고정하는 골든.
/// 이 테스트가 깨지면 백엔드 envelope 형태가 바뀐 것이다(조기 감지 앵커).
void main() {
  ApiException fromResponse(int status, Object? data, {Headers? headers}) {
    final req = RequestOptions(path: '/x');
    return ApiException.fromDio(
      DioException(
        requestOptions: req,
        response: Response(
          requestOptions: req,
          statusCode: status,
          data: data,
          headers: headers,
        ),
        type: DioExceptionType.badResponse,
      ),
    );
  }

  group('§3.4 중첩 envelope 계약', () {
    test('중첩 {"error":{code,message,trace_id}}를 필드별로 매핑한다', () {
      final ex = fromResponse(404, {
        'error': {
          'code': 'RESOURCE_NOT_FOUND',
          'message': '없음',
          'trace_id': 'trace-abc',
        },
      });
      expect(ex.code, ApiErrorCode.resourceNotFound);
      expect(ex.message, '없음');
      expect(ex.traceId, 'trace-abc');
      expect(ex.status, 404);
    });

    test('전 ErrorCode wire 문자열을 enum으로 매핑한다', () {
      const wire = {
        'UNAUTHORIZED': ApiErrorCode.unauthorized,
        'FORBIDDEN': ApiErrorCode.forbidden,
        'ONBOARDING_INCOMPLETE': ApiErrorCode.onboardingIncomplete,
        'RESOURCE_NOT_FOUND': ApiErrorCode.resourceNotFound,
        'VALIDATION_FAILED': ApiErrorCode.validationFailed,
        'CONFLICT': ApiErrorCode.conflict,
        'QUOTA_EXCEEDED': ApiErrorCode.quotaExceeded,
        'AI_KILL_SWITCH_ACTIVE': ApiErrorCode.aiKillSwitchActive,
        'SANDBOX_UNAVAILABLE': ApiErrorCode.sandboxUnavailable,
        'INTERNAL_ERROR':
            ApiErrorCode.unknown, // 프론트 enum에 INTERNAL_ERROR 없음 → unknown 폴백
      };
      wire.forEach((w, expected) {
        expect(ApiErrorCode.fromWire(w), expected, reason: 'wire=$w');
      });
    });

    test('알 수 없는 코드/누락은 unknown으로 폴백한다', () {
      expect(ApiErrorCode.fromWire('SOMETHING_NEW'), ApiErrorCode.unknown);
      expect(ApiErrorCode.fromWire(null), ApiErrorCode.unknown);
    });

    test('429 + retry-after 헤더를 retryAfterSeconds로 보존한다', () {
      final ex = fromResponse(
        429,
        {
          'error': {'code': 'QUOTA_EXCEEDED', 'message': '한도'},
        },
        headers: Headers.fromMap({
          'retry-after': ['45'],
        }),
      );
      expect(ex.code, ApiErrorCode.quotaExceeded);
      expect(ex.retryAfterSeconds, 45);
    });

    test('네트워크 타입은 network로 매핑한다', () {
      final ex = ApiException.fromDio(
        DioException(
          requestOptions: RequestOptions(path: '/x'),
          type: DioExceptionType.connectionError,
        ),
      );
      expect(ex.code, ApiErrorCode.network);
    });

    test('envelope 형태가 아닌 응답(비-Map/error 누락)은 방어 폴백한다', () {
      // error 키 누락
      final missing = fromResponse(500, {'foo': 'bar'});
      expect(missing.code, ApiErrorCode.unknown);
      expect(missing.message, '알 수 없는 오류가 발생했습니다.');
      expect(missing.status, 500);

      // 본문이 Map이 아님(HTML/텍스트)
      final nonMap = fromResponse(502, '<html>bad gateway</html>');
      expect(nonMap.code, ApiErrorCode.unknown);
      expect(nonMap.status, 502);
    });
  });
}
