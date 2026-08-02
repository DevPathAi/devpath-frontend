import 'package:dp_core/dp_core.dart';

/// [CommunitySearchPhase.idle] = 검색어 없음. 이때 화면은 **기존 목록 경로**를 그대로 쓴다 —
/// 검색은 목록을 대체하는 별도 모드이지 목록의 한 상태가 아니다.
enum CommunitySearchPhase { idle, loading, loaded, failed }

/// 커뮤니티 검색 상태. 목록(`CommunityState`)과 분리해 둔다 — 목록은 bare 배열이고
/// 검색은 envelope(총건수·페이지)이라 수명과 형태가 다르다.
class CommunitySearchState {
  const CommunitySearchState({
    this.query = '',
    this.items = const [],
    this.total = 0,
    this.page = 0,
    this.phase = CommunitySearchPhase.idle,
    this.loadingMore = false,
    this.error,
  });

  final String query;
  final List<CommunitySearchItem> items;
  final int total;
  final int page;
  final CommunitySearchPhase phase;

  /// "더 보기" 진행 중. 첫 로딩([CommunitySearchPhase.loading])과 달리 기존 결과를 유지한다.
  final bool loadingMore;
  final String? error;

  /// 다음 페이지가 남았는가. 서버가 준 총건수와 지금까지 받은 수를 비교한다.
  bool get hasMore => items.length < total;

  CommunitySearchState copyWith({
    String? query,
    List<CommunitySearchItem>? items,
    int? total,
    int? page,
    CommunitySearchPhase? phase,
    bool? loadingMore,
    String? error,
  }) => CommunitySearchState(
    query: query ?? this.query,
    items: items ?? this.items,
    total: total ?? this.total,
    page: page ?? this.page,
    phase: phase ?? this.phase,
    loadingMore: loadingMore ?? this.loadingMore,
    error: error,
  );
}
