/// 관리자 신고 목록 항목. 백엔드 `AdminReportView`(community-svc)와 1:1 대응한다.
///
/// 대상이 삭제됐으면 [targetTitle]·[targetExcerpt]·[targetPath] 가 null 이다 —
/// 신고는 다형 참조라 FK 가 없어 대상만 사라질 수 있다.
class AdminReport {
  const AdminReport({
    required this.id,
    required this.targetType,
    required this.targetId,
    required this.targetTitle,
    required this.targetExcerpt,
    required this.targetPath,
    required this.category,
    required this.reason,
    required this.reportCount,
    required this.status,
    required this.createdAt,
  });

  final int id;

  /// POST | ANSWER | COMMENT
  final String targetType;
  final int targetId;
  final String? targetTitle;
  final String? targetExcerpt;

  /// web 앱 기준 경로(`/community/{id}` 또는 `/community/post/{id}`). 서버가 조립해 준다.
  final String? targetPath;
  final String category;
  final String? reason;

  /// 같은 대상의 총 신고 수(status 무관). 1인 1회 제약이 있어 곧 신고자 수다.
  final int reportCount;

  /// OPEN | RESOLVED | REJECTED
  final String status;
  final String? createdAt;

  /// 서버 enum → 화면 표기. web 의 `CommunityReportCategory` 와 같은 대응이다.
  String get categoryLabel => switch (category) {
    'SPAM' => '스팸',
    'ABUSE' => '욕설',
    'AD' => '광고',
    'DUPLICATE' => '중복',
    'INAPPROPRIATE' => '부적절',
    _ => '기타',
  };

  String get targetTypeLabel => switch (targetType) {
    'ANSWER' => '답변',
    'COMMENT' => '댓글',
    _ => '글',
  };

  bool get isTargetGone => targetTitle == null;

  factory AdminReport.fromJson(Map<String, dynamic> json) => AdminReport(
    id: (json['id'] as num).toInt(),
    targetType: json['targetType'] as String,
    targetId: (json['targetId'] as num).toInt(),
    targetTitle: json['targetTitle'] as String?,
    targetExcerpt: json['targetExcerpt'] as String?,
    targetPath: json['targetPath'] as String?,
    category: json['category'] as String,
    reason: json['reason'] as String?,
    reportCount: (json['reportCount'] as num?)?.toInt() ?? 1,
    status: (json['status'] as String?) ?? 'OPEN',
    createdAt: json['createdAt'] as String?,
  );
}
