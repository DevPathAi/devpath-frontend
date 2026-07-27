/// 광고 일별 통계 행.
class AdStatsRow {
  const AdStatsRow({
    required this.date,
    required this.impressions,
    required this.clicks,
  });

  final DateTime date;
  final int impressions;
  final int clicks;

  factory AdStatsRow.fromJson(Map<String, dynamic> json) => AdStatsRow(
    date: DateTime.parse(json['date'] as String),
    impressions: (json['impressions'] as num).toInt(),
    clicks: (json['clicks'] as num).toInt(),
  );
}
