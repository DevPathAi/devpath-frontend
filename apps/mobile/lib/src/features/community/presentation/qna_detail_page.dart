import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/qna_detail_controller.dart';
import '../data/community_source.dart';
import '../state/qna_detail_state.dart';

/// 커뮤니티 Q&A 상세 — 질문 + 답변 스레드 + 투표/채택/답변 작성.
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
    // 액션 실패(예: 비작성자 채택 403)는 상세를 유지한 채 SnackBar로 표면화.
    ref.listen(qnaDetailControllerProvider, (prev, next) {
      if (next is QnaLoaded && next.actionError != null) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text(next.actionError!)));
      }
    });

    final s = ref.watch(qnaDetailControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Q&A')),
      body: switch (s) {
        QnaLoading() => const DpLoading(),
        QnaFailed(:final message) => DpError(message: message),
        QnaLoaded(:final detail, :final submitting) => _Loaded(
          detail: detail,
          submitting: submitting,
          answerCtrl: _answerCtrl,
        ),
      },
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

    return ListView(
      padding: const EdgeInsets.all(DpSpacing.lg),
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
          ],
        ),
        const SizedBox(height: DpSpacing.sm),
        _VoteBar(
          upvotes: detail.upvoteCount,
          downvotes: detail.downvoteCount,
          enabled: !submitting,
          onVote: (v) => notifier.vote(CommunityVoteTarget.post, detail.id, v),
        ),
        const SizedBox(height: DpSpacing.md),
        DpMarkdown(data: detail.bodyMd),
        if (detail.tags.isNotEmpty) ...[
          const SizedBox(height: DpSpacing.md),
          Wrap(
            spacing: DpSpacing.xs,
            children: [for (final t in detail.tags) Chip(label: Text('#$t'))],
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
    );
  }
}

class _AnswerCard extends StatelessWidget {
  const _AnswerCard({
    required this.answer,
    required this.questionSolved,
    required this.submitting,
    required this.onVote,
    required this.onAccept,
  });

  final CommunityAnswer answer;
  final bool questionSolved;
  final bool submitting;
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
