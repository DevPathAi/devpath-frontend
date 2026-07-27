/// admin 광고 목록/폼 모델. 백엔드 AdRow(응답)·AdRequest(요청) 양쪽을 담당.
class AdRow {
  const AdRow({
    this.id,
    required this.title,
    required this.imageUrl,
    required this.linkUrl,
    required this.slot,
    required this.weight,
    required this.status,
    required this.startsAt,
    required this.endsAt,
  });

  final int? id;
  final String title;
  final String? imageUrl;
  final String linkUrl;
  final String slot; // DASHBOARD_TOP | COMMUNITY_FEED | CONTENT_PAGE
  final int weight;
  final String status; // ACTIVE | PAUSED
  final DateTime? startsAt;
  final DateTime? endsAt;

  factory AdRow.fromJson(Map<String, dynamic> json) => AdRow(
    id: (json['id'] as num?)?.toInt(),
    title: json['title'] as String,
    imageUrl: json['imageUrl'] as String?,
    linkUrl: json['linkUrl'] as String,
    slot: json['slot'] as String,
    weight: (json['weight'] as num).toInt(),
    status: json['status'] as String,
    startsAt: _parseInstant(json['startsAt']),
    endsAt: _parseInstant(json['endsAt']),
  );

  /// POST/PUT 바디(AdRequest). id는 경로로 전달되므로 제외.
  Map<String, dynamic> toRequestJson() => {
    'title': title,
    'imageUrl': imageUrl,
    'linkUrl': linkUrl,
    'slot': slot,
    'weight': weight,
    'status': status,
    'startsAt': startsAt?.toUtc().toIso8601String(),
    'endsAt': endsAt?.toUtc().toIso8601String(),
  };

  AdRow copyWith({
    int? id,
    String? title,
    Object? imageUrl = _sentinel,
    String? linkUrl,
    String? slot,
    int? weight,
    String? status,
    Object? startsAt = _sentinel,
    Object? endsAt = _sentinel,
  }) => AdRow(
    id: id ?? this.id,
    title: title ?? this.title,
    imageUrl: imageUrl == _sentinel ? this.imageUrl : imageUrl as String?,
    linkUrl: linkUrl ?? this.linkUrl,
    slot: slot ?? this.slot,
    weight: weight ?? this.weight,
    status: status ?? this.status,
    startsAt: startsAt == _sentinel ? this.startsAt : startsAt as DateTime?,
    endsAt: endsAt == _sentinel ? this.endsAt : endsAt as DateTime?,
  );

  static const _sentinel = Object();

  static DateTime? _parseInstant(Object? v) =>
      v == null ? null : DateTime.parse(v as String);
}
