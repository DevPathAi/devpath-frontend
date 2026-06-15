import 'package:dp_core/dp_core.dart';

enum CommunityPhase { loading, loaded, failed }

class CommunityState {
  const CommunityState({
    this.posts = const [],
    this.nextCursor,
    this.phase = CommunityPhase.loading,
    this.loadingMore = false,
    this.error,
  });

  final List<CommunityPost> posts;
  final String? nextCursor;
  final CommunityPhase phase;
  final bool loadingMore;
  final String? error;

  bool get hasMore => nextCursor != null;

  CommunityState copyWith({
    List<CommunityPost>? posts,
    String? nextCursor,
    CommunityPhase? phase,
    bool? loadingMore,
    String? error,
  }) => CommunityState(
    posts: posts ?? this.posts,
    nextCursor: nextCursor, // 명시 전달(끝나면 null)
    phase: phase ?? this.phase,
    loadingMore: loadingMore ?? this.loadingMore,
    error: error,
  );
}
