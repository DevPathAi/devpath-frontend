import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/application/auth_controller.dart';
import '../../auth/state/auth_state.dart';
import '../application/qna_detail_controller.dart';
import '../data/community_source.dart';
import '../state/qna_detail_state.dart';
import 'lcs_context.dart';
import 'widgets/content_menu_button.dart';
import '../../support/presentation/supportable_error.dart';

class QnaDetailPage extends ConsumerStatefulWidget {
  const QnaDetailPage({super.key, required this.postId});

  /// 라우트 경로 파라미터(문자열) — 백엔드 id는 long이라 [int.parse]로 변환.
  final String postId;

  @override
  ConsumerState<QnaDetailPage> createState() => _QnaDetailPageState();
}

class _QnaDetailPageState extends ConsumerState<QnaDetailPage> {
  final _answerCtrl = TextEditingController();

  int get _id => int.parse(widget.postId);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(qnaDetailControllerProvider.notifier).load(_id),
    );
  }

  @override
  void dispose() {
    _answerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 액션 실패(예: 비작성자 채택 403)는 상세를 유지한 채 SnackBar로 표면화(무음 금지).
    ref.listen(qnaDetailControllerProvider, (prev, next) {
      if (next is QnaLoaded && next.actionError != null) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text(next.actionError!)));
      }
    });

    final s = ref.watch(qnaDetailControllerProvider);
    // 문서형 화면 — 헤더를 첫 sliver로 실어 본문과 함께 스크롤시킨다(DESIGN.md §9).
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: DpPageHeader(title: 'Q&A')),
          switch (s) {
            QnaLoading() => const SliverFillRemaining(
              hasScrollBody: false,
              child: DpLoading(),
            ),
            QnaFailed(:final message) => SliverFillRemaining(
              hasScrollBody: false,
              child: SupportableError(message: message),
            ),
            QnaLoaded(:final detail, :final submitting) => _Loaded(
              detail: detail,
              submitting: submitting,
              answerCtrl: _answerCtrl,
            ),
          },
        ],
      ),
    );
  }
}

class _Loaded extends ConsumerWidget {
  const _Loaded({
    required this.detail,
    required this.submitting,
    required this.answerCtrl,
  });

  final CommunityQuestionDetail detail;
  final bool submitting;
  final TextEditingController answerCtrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.dpColors;
    final notifier = ref.read(qnaDetailControllerProvider.notifier);

    // 페이지의 `CustomScrollView`에 직접 실리는 **sliver**를 반환한다 —
    // 여기서 `ListView`를 쓰면 중첩 스크롤이 되어 헤더가 밀려나지 않는다.
    return SliverPadding(
      padding: const EdgeInsets.all(DpSpacing.lg),
      sliver: SliverList.list(
        children: [
          Row(
            children: [
              if (detail.solved)
                Padding(
                  padding: const EdgeInsets.only(right: DpSpacing.xs),
                  child: Icon(DpIcons.stepDone, color: c.success),
                ),
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
                currentUserId: _currentUserId(ref),
                onEdit: () => context.go('/community/${detail.id}/edit'),
                onDeleted: () => context.go('/community'),
              ),
            ],
          ),
          const SizedBox(height: DpSpacing.sm),
          _VoteBar(
            upvotes: detail.upvoteCount,
            downvotes: detail.downvoteCount,
            enabled: !submitting,
            onVote: (v) =>
                notifier.vote(CommunityVoteTarget.post, detail.id, v),
          ),
          const SizedBox(height: DpSpacing.md),
          DpMarkdown(data: detail.bodyMd),
          const SizedBox(height: DpSpacing.sm),
          LcsAnswererPanel(questionId: detail.id),
          if (detail.tags.isNotEmpty) ...[
            const SizedBox(height: DpSpacing.md),
            Wrap(
              spacing: DpSpacing.xs,
              // 게시글 상세와 같은 요소이므로 같은 배선을 쓴다 — DpTag가 tag* 토큰의
              // 유일한 배선 지점이다(3-A 스펙 §7.2). 조사 단계에서 이 한 곳이 누락돼
              // 형제 화면끼리 태그 칩 색이 갈려 있었다.
              children: [for (final t in detail.tags) DpTag(label: '#$t')],
            ),
          ],
          const Divider(height: DpSpacing.xl),
          Text(
            '답변 ${detail.answers.length}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: DpSpacing.sm),
          for (final a in detail.answers)
            _AnswerCard(
              answer: a,
              questionSolved: detail.solved,
              submitting: submitting,
              currentUserId: _currentUserId(ref),
              onVote: (v) => notifier.vote(CommunityVoteTarget.answer, a.id, v),
              onAccept: () => notifier.accept(a.id),
            ),
          const SizedBox(height: DpSpacing.lg),
          _AnswerComposer(
            controller: answerCtrl,
            submitting: submitting,
            onSubmit: () {
              final body = answerCtrl.text.trim();
              if (body.isEmpty) return;
              notifier.submitAnswer(body);
              answerCtrl.clear();
            },
          ),
        ],
      ),
    );
  }
}

/// 현재 로그인 사용자 id(문자열). 미인증이면 null. 자기 콘텐츠 신고 메뉴를 감추는 데 쓴다.
String? _currentUserId(WidgetRef ref) {
  final auth = ref.watch(authControllerProvider);
  return auth is AuthAuthenticated ? auth.user.id : null;
}

class _AnswerCard extends StatelessWidget {
  const _AnswerCard({
    required this.answer,
    required this.questionSolved,
    required this.submitting,
    required this.currentUserId,
    required this.onVote,
    required this.onAccept,
  });

  final CommunityAnswer answer;
  final bool questionSolved;
  final bool submitting;
  final String? currentUserId;
  final ValueChanged<int> onVote;
  final VoidCallback onAccept;

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
                if (answer.aiGenerated)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DpSpacing.sm,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: c.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(DpSpacing.sm),
                    ),
                    child: Text(
                      '🤖 AI 초안',
                      style: TextStyle(
                        color: c.primaryText,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                if (answer.accepted) ...[
                  if (answer.aiGenerated) const SizedBox(width: DpSpacing.xs),
                  Icon(DpIcons.stepDone, size: 18, color: c.success),
                  const SizedBox(width: 2),
                  Text(
                    '채택됨',
                    style: TextStyle(
                      color: c.success,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
                const Spacer(),
                // 미해결 + 미채택 답변에만 채택 버튼 노출(OWNER는 백엔드가 강제, 비작성자는 403 SnackBar).
                if (!questionSolved && !answer.accepted)
                  TextButton(
                    onPressed: submitting ? null : onAccept,
                    child: const Text('채택'),
                  ),
                // AI 초안은 authorId 가 null 이라 「남의 것」으로 분류돼 신고만 보인다.
                ContentMenuButton(
                  kind: ContentKind.answer,
                  targetId: answer.id,
                  authorId: answer.authorId,
                  currentUserId: currentUserId,
                ),
              ],
            ),
            const SizedBox(height: DpSpacing.xs),
            DpMarkdown(data: answer.bodyMd),
            const SizedBox(height: DpSpacing.xs),
            _VoteBar(
              upvotes: answer.upvoteCount,
              enabled: !submitting,
              onVote: onVote,
            ),
          ],
        ),
      ),
    );
  }
}

class _VoteBar extends StatelessWidget {
  const _VoteBar({
    required this.upvotes,
    required this.enabled,
    required this.onVote,
    this.downvotes,
  });

  final int upvotes;
  final int? downvotes;
  final bool enabled;
  final ValueChanged<int> onVote;

  @override
  Widget build(BuildContext context) {
    final c = context.dpColors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(DpIcons.thumbUp, size: 18),
          tooltip: '추천',
          onPressed: enabled ? () => onVote(1) : null,
        ),
        Text('$upvotes', style: TextStyle(color: c.textSecondary)),
        const SizedBox(width: DpSpacing.sm),
        IconButton(
          icon: const Icon(DpIcons.thumbDown, size: 18),
          tooltip: '비추천',
          onPressed: enabled ? () => onVote(-1) : null,
        ),
        if (downvotes != null)
          Text('$downvotes', style: TextStyle(color: c.textSecondary)),
      ],
    );
  }
}

class _AnswerComposer extends StatelessWidget {
  const _AnswerComposer({
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
            labelText: '답변 작성',
            hintText: '도움이 될 답변을 남겨보세요',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: DpSpacing.sm),
        FilledButton.icon(
          onPressed: submitting ? null : onSubmit,
          icon: const Icon(DpIcons.send, size: 18),
          label: const Text('답변 등록'),
        ),
      ],
    );
  }
}
