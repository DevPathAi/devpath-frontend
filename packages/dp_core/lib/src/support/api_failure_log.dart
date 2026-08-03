import 'dart:collection';

/// 제보에 첨부할 API 실패 1건. **기록 시점에 이미 마스킹된 값만** 담는다 —
/// 버퍼에 원문을 두지 않으면 이후 어떤 경로로도 원문이 새지 않는다.
class ApiFailureEntry {
  const ApiFailureEntry({
    required this.method,
    required this.path,
    required this.occurredAt,
    this.statusCode,
    this.errorCode,
    this.traceId,
    this.message,
  });

  final String method;

  /// 쿼리스트링이 제거된 경로.
  final String path;

  /// 네트워크 실패면 null — 이 구분 자체가 진단 정보다.
  final int? statusCode;
  final String? errorCode;
  final String? traceId;

  /// 마스킹 후 500자로 절단된 응답 message.
  final String? message;

  final DateTime occurredAt;

  /// 접수 요청의 `context.failures[]` 원소 형태(서버 SupportCreateRequest.Failure 와 대응).
  Map<String, dynamic> toJson() => {
    'method': method,
    'path': path,
    'statusCode': statusCode,
    'errorCode': errorCode,
    'traceId': traceId,
    'message': message,
    'occurredAt': occurredAt.toUtc().toIso8601String(),
  };
}

/// 최근 실패 링버퍼. 메모리 전용 — 앱 재시작 시 소멸한다(영속화하지 않는다).
class ApiFailureLog {
  ApiFailureLog({this.capacity = 10});

  final int capacity;
  final ListQueue<ApiFailureEntry> _entries = ListQueue<ApiFailureEntry>();

  void add(ApiFailureEntry entry) {
    if (_entries.length >= capacity) {
      _entries.removeFirst();
    }
    _entries.addLast(entry);
  }

  /// **0 = 가장 최근.** 서버 `seq` 와 같은 순서다.
  List<ApiFailureEntry> get recent =>
      List<ApiFailureEntry>.unmodifiable(_entries.toList().reversed);

  int get length => _entries.length;

  void clear() => _entries.clear();
}
