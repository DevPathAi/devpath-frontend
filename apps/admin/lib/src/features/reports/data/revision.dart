/// 관리자 수정 이력 항목. 백엔드 `RevisionView`(community-svc)와 1:1 대응한다.
///
/// 신고 처리 때 「답변을 받고 질문을 통째로 바꿨는가」를 확인하는 근거다.
/// 이용자에게는 열지 않는다(스펙 §10 범위 밖).
class AdminRevision {
  const AdminRevision({
    required this.targetType,
    required this.targetId,
    required this.title,
    required this.bodyMd,
    required this.editedBy,
    required this.createdAt,
  });

  /// POST | ANSWER | COMMENT
  final String targetType;
  final int targetId;

  /// 답변·댓글 리비전에는 제목이 없다.
  final String? title;
  final String? bodyMd;
  final int editedBy;
  final String? createdAt;

  factory AdminRevision.fromJson(Map<String, dynamic> json) => AdminRevision(
    targetType: json['targetType'] as String,
    targetId: (json['targetId'] as num).toInt(),
    title: json['title'] as String?,
    bodyMd: json['bodyMd'] as String?,
    editedBy: (json['editedBy'] as num).toInt(),
    createdAt: json['createdAt'] as String?,
  );
}
