import 'package:dp_core/dp_core.dart';

/// 사용자가 입력한 부분. 수집 컨텍스트와 분리해 두면 다이얼로그가 입력만 다룬다.
class SupportDraft {
  const SupportDraft({
    required this.type,
    required this.title,
    required this.body,
  });

  /// ERROR | INQUIRY
  final String type;
  final String title;
  final String body;
}

/// 자동 수집되는 부분. `toJson()` 이 접수 요청의 `context` 객체가 된다.
class SupportContext {
  const SupportContext({
    required this.pagePath,
    required this.appVersion,
    required this.userAgent,
    required this.viewport,
    required this.occurredAt,
    required this.failures,
    this.traceId,
    this.errorCode,
  });

  final String pagePath;
  final String appVersion;
  final String userAgent;
  final String viewport;
  final DateTime occurredAt;

  /// 링버퍼의 최근 실패(0 = 가장 최근). 이미 마스킹된 값이다.
  final List<ApiFailureEntry> failures;

  /// 오류 화면에서 진입한 경우에만 채워진다.
  /// 서버는 현재 trace_id 를 항상 null 로 보낸다(분산 트레이싱 미도입) — 배관만 있다.
  final String? traceId;
  final String? errorCode;

  Map<String, dynamic> toJson() => {
    'pagePath': _stripQuery(pagePath),
    'appVersion': appVersion,
    'userAgent': userAgent,
    'viewport': viewport,
    'traceId': traceId,
    'errorCode': errorCode,
    'occurredAt': occurredAt.toUtc().toIso8601String(),
    'failures': [for (final f in failures) f.toJson()],
  };

  static String _stripQuery(String path) {
    final i = path.indexOf('?');
    return i < 0 ? path : path.substring(0, i);
  }
}
