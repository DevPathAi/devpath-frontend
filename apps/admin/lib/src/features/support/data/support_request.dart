/// 관리자 목록 행. 백엔드 `AdminSupportRow`(platform-svc)와 1:1 대응한다.
class SupportRequestRow {
  const SupportRequestRow({
    required this.id,
    required this.type,
    required this.title,
    required this.status,
    required this.failureCount,
    this.pagePath,
    this.reporterId,
    this.createdAt,
  });

  final int id;

  /// ERROR | INQUIRY
  final String type;
  final String title;

  /// OPEN | IN_PROGRESS | RESOLVED | WONTFIX
  final String status;
  final int failureCount;
  final String? pagePath;
  final int? reporterId;
  final String? createdAt;

  String get typeLabel => type == 'INQUIRY' ? '문의' : '오류';

  /// **명사** — 상태 표기·필터용. 전이 버튼(동사)과 낱말이 겹치지 않게 한다.
  String get statusLabel => switch (status) {
    'IN_PROGRESS' => '처리중',
    'RESOLVED' => '처리됨',
    'WONTFIX' => '보류',
    _ => '접수됨',
  };

  factory SupportRequestRow.fromJson(Map<String, dynamic> json) =>
      SupportRequestRow(
        id: (json['id'] as num).toInt(),
        type: json['type'] as String,
        title: json['title'] as String,
        status: (json['status'] as String?) ?? 'OPEN',
        failureCount: (json['failureCount'] as num?)?.toInt() ?? 0,
        pagePath: json['pagePath'] as String?,
        reporterId: (json['reporterId'] as num?)?.toInt(),
        createdAt: json['createdAt'] as String?,
      );
}

/// 상세의 실패 1행.
class SupportFailure {
  const SupportFailure({
    required this.seq,
    required this.method,
    required this.path,
    required this.occurredAt,
    this.statusCode,
    this.errorCode,
    this.traceId,
    this.message,
  });

  final int seq;
  final String method;
  final String path;
  final String? occurredAt;
  final int? statusCode;
  final String? errorCode;
  final String? traceId;
  final String? message;

  /// null 은 상태코드가 없는 실패(타임아웃·연결 단절)다.
  String get statusLabel => statusCode == null ? '네트워크 실패' : '$statusCode';

  factory SupportFailure.fromJson(Map<String, dynamic> json) => SupportFailure(
    seq: (json['seq'] as num).toInt(),
    method: json['method'] as String,
    path: json['path'] as String,
    occurredAt: json['occurredAt'] as String?,
    statusCode: (json['statusCode'] as num?)?.toInt(),
    errorCode: json['errorCode'] as String?,
    traceId: json['traceId'] as String?,
    message: json['message'] as String?,
  );
}

/// 관리자 상세. 백엔드 `AdminSupportDetail` 과 1:1 대응한다.
class SupportRequestDetail {
  const SupportRequestDetail({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.status,
    required this.failures,
    this.pagePath,
    this.appVersion,
    this.userAgent,
    this.viewport,
    this.traceId,
    this.errorCode,
    this.occurredAt,
    this.reporterId,
    this.adminNote,
    this.handledBy,
    this.handledAt,
    this.createdAt,
  });

  final int id;
  final String type;
  final String title;
  final String body;
  final String status;
  final List<SupportFailure> failures;
  final String? pagePath;
  final String? appVersion;
  final String? userAgent;
  final String? viewport;
  final String? traceId;
  final String? errorCode;
  final String? occurredAt;
  final int? reporterId;
  final String? adminNote;
  final int? handledBy;
  final String? handledAt;
  final String? createdAt;

  factory SupportRequestDetail.fromJson(Map<String, dynamic> json) =>
      SupportRequestDetail(
        id: (json['id'] as num).toInt(),
        type: json['type'] as String,
        title: json['title'] as String,
        body: (json['body'] as String?) ?? '',
        status: (json['status'] as String?) ?? 'OPEN',
        failures: [
          for (final o in (json['failures'] as List? ?? const []))
            SupportFailure.fromJson((o as Map).cast<String, dynamic>()),
        ],
        pagePath: json['pagePath'] as String?,
        appVersion: json['appVersion'] as String?,
        userAgent: json['userAgent'] as String?,
        viewport: json['viewport'] as String?,
        traceId: json['traceId'] as String?,
        errorCode: json['errorCode'] as String?,
        occurredAt: json['occurredAt'] as String?,
        reporterId: (json['reporterId'] as num?)?.toInt(),
        adminNote: json['adminNote'] as String?,
        handledBy: (json['handledBy'] as num?)?.toInt(),
        handledAt: json['handledAt'] as String?,
        createdAt: json['createdAt'] as String?,
      );
}
