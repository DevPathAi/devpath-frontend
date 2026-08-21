import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/community_source.dart';
import '../presentation/widgets/content_menu_button.dart';
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

  /// 댓글 수정(인라인). 성공하면 상세를 재조회한다 — 서버가 렌더한 bodyHtml 과 갱신
  /// 시각이 응답 하나로는 스레드 전체에 반영되지 않는다(addComment 와 같은 방침).
  ///
  /// 빈 본문은 서버를 부르지 않고 막는다. 서버도 400 을 내지만 왕복이 낭비다.
  Future<void> updateComment(int commentId, String bodyMd) async {
    final body = bodyMd.trim();
    if (body.isEmpty) return;
    state = state.copyWith(submitting: true);
    try {
      await ref.read(commentUpdateProvider)(commentId, body);
      final detail = await ref.read(postDetailFetchProvider)(postId);
      state = state.copyWith(detail: detail, submitting: false);
    } on ApiException catch (e) {
      state = state.copyWith(submitting: false, error: contentActionMessage(e));
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
