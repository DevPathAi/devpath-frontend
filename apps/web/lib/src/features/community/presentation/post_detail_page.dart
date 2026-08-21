import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../../auth/state/auth_state.dart';
import '../application/post_detail_controller.dart';
import '../state/post_detail_state.dart';
import 'widgets/content_menu_button.dart';
import '../../support/presentation/supportable_error.dart';

/// 일반 게시글(FREE/FEEDBACK) 상세 — 마크다운 본문·태그·추천·댓글 스레드.
/// Q&A(qna_detail_page)와 달리 답변/채택 대신 댓글로 소통한다.
class PostDetailPage extends ConsumerStatefulWidget {
  const PostDetailPage({super.key, required this.postId});

  /// 라우트 경로 파라미터(문자열) — 백엔드 id는 long이라 [int.parse]로 변환.
  final String postId;

  @override
  ConsumerState<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends ConsumerState<PostDetailPage> {
  final _commentCtrl = TextEditingController();

  int get _id => int.parse(widget.postId);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(postDetailControllerProvider(_id).notifier).load(),
    );
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 액션 실패는 상세를 유지한 채 SnackBar로 표면화(무음 금지).
    ref.listen(postDetailControllerProvider(_id), (prev, next) {
      if (next.error != null && next.phase == PostDetailPhase.loaded) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text(next.error!)));
      }
    });

    final s = ref.watch(postDetailControllerProvider(_id));
    final notifier = ref.read(postDetailControllerProvider(_id).notifier);

    // 문서형 화면 — 헤더를 첫 sliver로 실어 본문과 함께 스크롤시킨다(DESIGN.md §9).
    // 본문은 자체 스크롤을 갖지 않는다(중첩 스크롤이면 헤더가 밀려나지 않는다).
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: DpPageHeader(title: '게시글')),
          switch (s.phase) {
            PostDetailPhase.loading => const SliverFillRemaining(
              hasScrollBody: false,
              child: DpLoading(),
            ),
            PostDetailPhase.failed => SliverFillRemaining(
              hasScrollBody: false,
              child: SupportableError(
                message: s.error ?? '불러오지 못했어요',
                onRetry: notifier.load,
              ),
            ),
            PostDetailPhase.loaded when s.detail != null => _Loaded(
              detail: s.detail!,
              submitting: s.submitting,
              currentUserId: switch (ref.watch(authControllerProvider)) {
                AuthAuthenticated(:final user) => user.id,
                _ => null,
              },
              commentCtrl: _commentCtrl,
              onUpvote: notifier.upvote,
              onComment: () {
                final body = _commentCtrl.text.trim();
                if (body.isEmpty) return;
                notifier.addComment(body);
                _commentCtrl.clear();
              },
            ),
            PostDetailPhase.loaded => const SliverFillRemaining(
              hasScrollBody: false,
              child: DpLoading(),
            ),
          },
        ],
      ),
    );
  }
}

class _Loaded extends StatelessWidget {
  const _Loaded({
    required this.detail,
    required this.submitting,
    required this.currentUserId,
    required this.commentCtrl,
    required this.onUpvote,
    required this.onComment,
  });

  final CommunityPostDetail detail;
  final bool submitting;

  /// 자기 콘텐츠 신고 메뉴를 감추는 데 쓴다. 미인증이면 null.
  final String? currentUserId;
  final TextEditingController commentCtrl;
  final VoidCallback onUpvote;
  final VoidCallback onComment;

  /// 페이지의 `CustomScrollView`에 직접 실리는 **sliver**를 반환한다 —
  /// 여기서 `ListView`를 쓰면 중첩 스크롤이 되어 헤더가 밀려나지 않는다.
  @override
  Widget build(BuildContext context) {
    final c = context.dpColors;
    return SliverPadding(
      padding: const EdgeInsets.all(DpSpacing.lg),
      sliver: SliverList.list(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  detail.title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              ContentMenuButton(
                kind: ContentKind.post,
                targetId: detail.id,
                authorId: detail.authorId,
                currentUserId: currentUserId,
              ),
            ],
          ),
          if (detail.tags.isNotEmpty) ...[
            const SizedBox(height: DpSpacing.sm),
            Wrap(
              spacing: DpSpacing.xs,
              children: [for (final t in detail.tags) DpTag(label: '#$t')],
            ),
          ],
          const SizedBox(height: DpSpacing.sm),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(DpIcons.thumbUp, size: 18),
                tooltip: '추천',
                onPressed: submitting ? null : onUpvote,
              ),
              Text(
                '${detail.upvoteCount}',
                style: TextStyle(color: c.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: DpSpacing.md),
          DpMarkdown(data: detail.bodyMd),
          const Divider(height: DpSpacing.xl),
          Text(
            '댓글 ${detail.comments.length}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: DpSpacing.sm),
          for (final cm in detail.comments)
            _CommentCard(comment: cm, currentUserId: currentUserId),
          const SizedBox(height: DpSpacing.lg),
          _CommentComposer(
            controller: commentCtrl,
            submitting: submitting,
            onSubmit: onComment,
          ),
        ],
      ),
    );
  }
}

class _CommentCard extends StatelessWidget {
  const _CommentCard({required this.comment, required this.currentUserId});

  final CommunityComment comment;
  final String? currentUserId;

  @override
  Widget build(BuildContext context) {
    final c = context.dpColors;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(DpSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    comment.authorId == null ? '익명' : '작성자 ${comment.authorId}',
                    style: TextStyle(color: c.textSecondary, fontSize: 12),
                  ),
                ),
                ContentMenuButton(
                  kind: ContentKind.comment,
                  targetId: comment.id,
                  authorId: comment.authorId,
                  currentUserId: currentUserId,
                ),
              ],
            ),
            const SizedBox(height: DpSpacing.xs),
            DpMarkdown(data: comment.bodyMd),
            const SizedBox(height: DpSpacing.xs),
            Text(
              comment.createdAt,
              style: TextStyle(color: c.textSecondary, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentComposer extends StatelessWidget {
  const _CommentComposer({
    required this.controller,
    required this.submitting,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool submitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        TextField(
          controller: controller,
          minLines: 2,
          maxLines: 6,
          enabled: !submitting,
          decoration: const InputDecoration(
            labelText: '댓글 작성',
            hintText: '의견을 남겨보세요',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: DpSpacing.sm),
        FilledButton.icon(
          onPressed: submitting ? null : onSubmit,
          icon: const Icon(DpIcons.send, size: 18),
          label: const Text('댓글 등록'),
        ),
      ],
    );
  }
}
