import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/community_source.dart';
import '../state/post_detail_state.dart';

/// 일반 게시글(FREE/FEEDBACK) 상세 + 액션(댓글/추천). 액션은 void/단건이라 성공 후
/// **상세를 재조회**해 최신 댓글 스레드·카운트를 반영한다(qna_detail_controller 패턴 승계).
///
/// riverpod 3.x의 class-based family notifier는 `Notifier<State>`를 확장하고 family
/// 인자를 **생성자**로 받는다(riverpod 3.3.2 `SyncFamily(this.arg)` 예제 확인). 이로써
/// 게시글 id별로 독립 상태를 갖는다.
class PostDetailController extends Notifier<PostDetailState> {
  PostDetailController(this.postId);

  final int postId;

  @override
  PostDetailState build() => const PostDetailState();

  Future<void> load() async {
    state = state.copyWith(phase: PostDetailPhase.loading);
    try {
      final detail = await ref.read(postDetailFetchProvider)(postId);
      state = state.copyWith(detail: detail, phase: PostDetailPhase.loaded);
    } on ApiException catch (e) {
      state = state.copyWith(phase: PostDetailPhase.failed, error: e.message);
    }
  }

  Future<void> addComment(String bodyMd) async {
    if (bodyMd.trim().isEmpty) return;
    state = state.copyWith(submitting: true);
    try {
      await ref.read(commentCreateProvider)(postId, bodyMd.trim());
      final detail = await ref.read(postDetailFetchProvider)(postId);
      state = state.copyWith(detail: detail, submitting: false);
    } on ApiException catch (e) {
      state = state.copyWith(submitting: false, error: e.message);
    }
  }

  Future<void> upvote() async {
    try {
      await ref.read(communityVoteProvider)(
        target: CommunityVoteTarget.post,
        id: postId,
        value: 1,
      );
      await load();
    } on ApiException catch (e) {
      state = state.copyWith(error: e.message);
    }
  }
}

final postDetailControllerProvider =
    NotifierProvider.family<PostDetailController, PostDetailState, int>(
      PostDetailController.new,
    );
