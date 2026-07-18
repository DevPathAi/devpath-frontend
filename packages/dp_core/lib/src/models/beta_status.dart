/// 베타 승인 상태(GET /beta/status). 서버 status 문자열을 enum으로 매핑한다.
enum BetaStatusKind { pending, approved, expired }

class BetaStatus {
  const BetaStatus({required this.status, this.provider});

  final BetaStatusKind status;

  /// 승인 시 자동 재-OAuth에 쓸 대표 provider(소문자, 예: 'github'/'google'). 없으면 null.
  final String? provider;

  factory BetaStatus.fromJson(Map<String, dynamic> json) => BetaStatus(
    status: _kindFromString(json['status'] as String?),
    provider: json['provider'] as String?,
  );

  static BetaStatusKind _kindFromString(String? raw) {
    switch (raw) {
      case 'APPROVED':
        return BetaStatusKind.approved;
      case 'PENDING':
        return BetaStatusKind.pending;
      default:
        return BetaStatusKind.expired;
    }
  }
}
