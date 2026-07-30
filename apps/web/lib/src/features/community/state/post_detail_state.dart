import 'package:dp_core/dp_core.dart';

enum PostDetailPhase { loading, loaded, failed }

/// 일반 게시글(FREE/FEEDBACK) 상세 상태. Q&A와 달리 댓글로 소통하며 채택/답변이 없다.
class PostDetailState {
  const PostDetailState({
    this.detail,
    this.phase = PostDetailPhase.loading,
    this.submitting = false,
    this.error,
  });

  final CommunityPostDetail? detail;
  final PostDetailPhase phase;
  final bool submitting;
  final String? error;

  PostDetailState copyWith({
    CommunityPostDetail? detail,
    PostDetailPhase? phase,
    bool? submitting,
    String? error,
  }) => PostDetailState(
    detail: detail ?? this.detail,
    phase: phase ?? this.phase,
    submitting: submitting ?? this.submitting,
    error: error,
  );
}
