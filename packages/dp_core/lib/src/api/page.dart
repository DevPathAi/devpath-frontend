/// 커서 기반 페이지(스펙 §3 — {data, nextCursor, limit}, limit 기본 20/최대 100).
/// cursor는 opaque(해석 금지).
class Page<T> {
  const Page({required this.data, required this.limit, this.nextCursor});

  final List<T> data;
  final String? nextCursor;
  final int limit;

  bool get hasMore => nextCursor != null;

  factory Page.fromJson(
    Map<String, dynamic> json,
    T Function(Object? item) fromItem,
  ) {
    final list = (json['data'] as List? ?? const []).map(fromItem).toList();
    return Page(
      data: list,
      nextCursor: json['nextCursor'] as String?,
      limit: (json['limit'] as int?) ?? 20,
    );
  }
}
