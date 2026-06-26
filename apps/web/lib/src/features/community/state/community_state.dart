import 'package:dp_core/dp_core.dart';

enum CommunityPhase { loading, loaded, failed }

/// Q&A 목록 상태. 백엔드 `GET /community/posts`가 **bare 배열**(커서/페이지네이션 없음)이라
/// 슬라이스 #8 MVP는 단일 로드만 둔다(과거 목 시절 loadMore/nextCursor 제거 — 백엔드 미제공).
class CommunityState {
  const CommunityState({
    this.posts = const [],
    this.phase = CommunityPhase.loading,
    this.error,
  });

  final List<CommunityPostSummary> posts;
  final CommunityPhase phase;
  final String? error;
}
