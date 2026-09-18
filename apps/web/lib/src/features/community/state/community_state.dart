import 'package:dp_core/dp_core.dart';

enum CommunityPhase { loading, loaded, failed }

/// 보드 필터. all=전체(board 미전달), 나머지는 백엔드 boardType 값.
enum CommunityBoard {
  all(null, '전체'),
  free('FREE', '자유게시판'),
  qna('QNA', 'Q/A'),
  feedback('FEEDBACK', '피드백');

  const CommunityBoard(this.value, this.label);
  final String? value;
  final String label;
}

/// 목록 정렬. 백엔드 목록 API 는 `sort` 를 받기만 하고 항상 최신순으로 돌려준다
/// (community-svc `QuestionService.list`). 목록이 페이지네이션 없는 전체 배열이라
/// 클라이언트 정렬이 곧 정확한 정렬이다.
enum CommunitySort {
  latest('최신순'),
  upvotes('추천순');

  const CommunitySort(this.label);
  final String label;
}

/// 통합 피드 상태. 백엔드 `GET /community/posts`가 **bare 배열**(커서/페이지네이션 없음)이라
/// 단일 로드만 둔다. [board] 필터로 전 보드(QNA/FREE/FEEDBACK)를 섞어 보거나 한 보드만 본다.
class CommunityState {
  const CommunityState({
    this.posts = const [],
    this.phase = CommunityPhase.loading,
    this.board = CommunityBoard.all,
    this.sort = CommunitySort.latest,
    this.error,
  });

  /// 서버가 준 순서(최신순) 그대로.
  final List<CommunityPostSummary> posts;
  final CommunityPhase phase;
  final CommunityBoard board;
  final CommunitySort sort;
  final String? error;

  /// 화면에 그릴 순서. 추천순의 동률은 서버 순서(최신 우선)를 지킨다 —
  /// `List.sort` 는 안정 정렬을 보장하지 않아 원래 위치를 2차 키로 쓴다.
  List<CommunityPostSummary> get visiblePosts {
    if (sort == CommunitySort.latest) return posts;
    final order = [for (var i = 0; i < posts.length; i++) i]
      ..sort((a, b) {
        final byUpvotes = posts[b].upvoteCount.compareTo(posts[a].upvoteCount);
        return byUpvotes != 0 ? byUpvotes : a.compareTo(b);
      });
    return [for (final i in order) posts[i]];
  }

  CommunityState copyWith({
    List<CommunityPostSummary>? posts,
    CommunityPhase? phase,
    CommunityBoard? board,
    CommunitySort? sort,
    String? error,
  }) => CommunityState(
    posts: posts ?? this.posts,
    phase: phase ?? this.phase,
    board: board ?? this.board,
    sort: sort ?? this.sort,
    error: error,
  );
}
