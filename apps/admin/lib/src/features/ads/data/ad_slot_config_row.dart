/// admin 슬롯 설정 모델. 백엔드 AdSlotConfigView(응답)·AdSlotConfigRequest(요청) 양쪽.
class AdSlotConfigRow {
  const AdSlotConfigRow({
    required this.slot,
    required this.source,
    required this.adsenseSlotId,
  });

  final String slot; // DASHBOARD_TOP | COMMUNITY_FEED | CONTENT_PAGE
  final String source; // HOUSE | ADSENSE | OFF
  final String? adsenseSlotId;

  factory AdSlotConfigRow.fromJson(Map<String, dynamic> json) =>
      AdSlotConfigRow(
        slot: json['slot'] as String,
        source: json['source'] as String,
        adsenseSlotId: json['adsenseSlotId'] as String?,
      );

  /// PUT 바디. slot은 경로로 전달되므로 제외.
  Map<String, dynamic> toRequestJson() => {
    'source': source,
    'adsenseSlotId': adsenseSlotId,
  };

  AdSlotConfigRow copyWith({
    String? source,
    Object? adsenseSlotId = _sentinel,
  }) => AdSlotConfigRow(
    slot: slot,
    source: source ?? this.source,
    adsenseSlotId: adsenseSlotId == _sentinel
        ? this.adsenseSlotId
        : adsenseSlotId as String?,
  );

  static const _sentinel = Object();
}
