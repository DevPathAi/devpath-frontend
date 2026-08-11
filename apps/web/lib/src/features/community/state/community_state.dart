import 'package:dp_core/dp_core.dart';

enum CommunityPhase { loading, loaded, failed }

/// 보드 필터. all=전체(board 미전달), 나머지는 백엔드 boardType 값.
enum CommunityBoard {
  all(null, '전체'),
  qna('QNA', 'Q&A'),
  free('FREE', '자유'),
  feedback('FEEDBACK', '피드백');

  const CommunityBoard(this.value, this.label);
  final String? value;
  final String label;
}

/// 통합 피드 상태. 백엔드 `GET /community/posts`가 **bare 배열**(커서/페이지네이션 없음)이라
/// 단일 로드만 둔다. [board] 필터로 전 보드(QNA/FREE/FEEDBACK)를 섞어 보거나 한 보드만 본다.
class CommunityState {
  const CommunityState({
    this.posts = const [],
    this.phase = CommunityPhase.loading,
    this.board = CommunityBoard.all,
    this.error,
  });

  final List<CommunityPostSummary> posts;
  final CommunityPhase phase;
  final CommunityBoard board;
  final String? error;

  CommunityState copyWith({
    List<CommunityPostSummary>? posts,
    CommunityPhase? phase,
    CommunityBoard? board,
    String? error,
  }) => CommunityState(
    posts: posts ?? this.posts,
    phase: phase ?? this.phase,
    board: board ?? this.board,
    error: error,
  );
}
