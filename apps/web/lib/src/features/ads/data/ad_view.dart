/// 서빙 광고 뷰(읽기 전용). 백엔드 AdView 계약.
class AdView {
  const AdView({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.linkUrl,
    required this.slot,
  });

  final int id;
  final String title;
  final String? imageUrl;
  final String linkUrl;
  final String slot;

  factory AdView.fromJson(Map<String, dynamic> json) => AdView(
    id: (json['id'] as num).toInt(),
    title: json['title'] as String,
    imageUrl: json['imageUrl'] as String?,
    linkUrl: json['linkUrl'] as String,
    slot: json['slot'] as String,
  );
}
