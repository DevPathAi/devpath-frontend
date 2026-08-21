import 'dart:async';

import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../../auth/state/auth_state.dart';
import '../../mission/state/mobile_mission_route.dart';
import '../application/qna_detail_controller.dart';
import '../data/community_source.dart';
import '../state/qna_detail_state.dart';

/// 커뮤니티 Q&A 상세 — 질문 + 답변 스레드 + 투표/채택/답변 작성.
class QnaDetailPage extends ConsumerStatefulWidget {
  const QnaDetailPage({super.key, required this.postId});

  /// 라우트 경로 파라미터. Positive JavaScript-safe integer만 허용한다.
  final String postId;

  @override
  ConsumerState<QnaDetailPage> createState() => _QnaDetailPageState();
}

class _QnaDetailPageState extends ConsumerState<QnaDetailPage> {
  final _answerCtrl = TextEditingController();

  int? get _id => _parsePostId(widget.postId);

  @override
  void initState() {
    super.initState();
    ref.listenManual(currentOwnerKeyProvider, (previous, next) {
      if (previous != next) _answerCtrl.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final id = _id;
      if (id != null) {
        ref.read(qnaDetailControllerProvider.notifier).load(id);
      }
    });
  }

  @override
  void didUpdateWidget(covariant QnaDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.postId == widget.postId) return;
    _answerCtrl.clear();
    final expectedPostId = widget.postId;
    final id = _id;
    scheduleMicrotask(() {
      if (!mounted || widget.postId != expectedPostId) return;
      final notifier = ref.read(qnaDetailControllerProvider.notifier)..reset();
      if (id != null) unawaited(notifier.load(id));
    });
  }

  @override
  void dispose() {
    _answerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final id = _id;
    if (id == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Q&A')),
        body: const DpError(message: '잘못된 질문 경로입니다.'),
      );
    }
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
        QnaLoaded(:final detail, :final submitting) when detail.id == id =>
          _Loaded(
            detail: detail,
            submitting: submitting,
            answerCtrl: _answerCtrl,
          ),
        QnaLoaded() => const DpLoading(),
      },
    );
  }
}

int? _parsePostId(String value) {
  if (!RegExp(r'^[1-9][0-9]*$').hasMatch(value)) return null;
  final parsed = int.tryParse(value);
  if (parsed == null || parsed > MobileMissionRoute.maxSafeInteger) return null;
  return parsed;
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
    // 내 답변에만 수정·삭제를 보인다. 모르면 보이지 않는다 — 서버가 최종 방어선이다.
    final currentUserId = switch (ref.watch(authControllerProvider)) {
      AuthAuthenticated(:final user) => user.id,
      _ => null,
    };

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
            isMine:
                a.authorId != null &&
                currentUserId != null &&
                a.authorId.toString() == currentUserId,
            onVote: (v) => notifier.vote(CommunityVoteTarget.answer, a.id, v),
            onAccept: () => notifier.accept(a.id),
            onSave: (body) => notifier.updateAnswer(a.id, body),
            onDelete: () => notifier.deleteAnswer(a.id),
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

/// 답변 카드. 모바일에는 Quill 이 없어 편집 UI 가 웹보다 단순하다 — 같은 TextField 에
/// 기존 bodyMd 를 채운다.
///
/// ★알려진 비대칭★ 웹에서 리치로 쓴 글을 여기서 열면 원시 마크다운이 보인다.
/// 마크다운이므로 틀린 표시는 아니고 이번 범위에서 해소하지 않는다(스펙 §7).
class _AnswerCard extends StatefulWidget {
  const _AnswerCard({
    required this.answer,
    required this.questionSolved,
    required this.submitting,
    required this.isMine,
    required this.onVote,
    required this.onAccept,
    required this.onSave,
    required this.onDelete,
  });

  final CommunityAnswer answer;
  final bool questionSolved;
  final bool submitting;

  /// 현재 사용자가 이 답변의 작성자인가. 모르면 false — 서버 검증이 최종 방어선이다.
  final bool isMine;
  final ValueChanged<int> onVote;
  final VoidCallback onAccept;

  /// 인라인 편집 저장. 카드는 서버를 직접 부르지 않고 컨트롤러에 위임한다.
  final ValueChanged<String> onSave;
  final VoidCallback onDelete;

  @override
  State<_AnswerCard> createState() => _AnswerCardState();
}

class _AnswerCardState extends State<_AnswerCard> {
  bool _editing = false;
  late final TextEditingController _ctrl = TextEditingController(
    text: widget.answer.bodyMd,
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('삭제할까요?'),
        content: const Text('삭제하면 되돌릴 수 없어요.'),
        actions: [
          TextButton(
            key: const ValueKey('answer-delete-cancel'),
            onPressed: () => Navigator.of(d).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            key: const ValueKey('answer-delete-confirm'),
            onPressed: () => Navigator.of(d).pop(true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok == true) widget.onDelete();
  }

  @override
  Widget build(BuildContext context) {
    final answer = widget.answer;
    if (answer.deleted) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(DpSpacing.md),
          child: Text(
            '삭제된 내용입니다',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).disabledColor,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }
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
                if (!widget.questionSolved && !answer.accepted)
                  TextButton(
                    onPressed: widget.submitting ? null : widget.onAccept,
                    child: const Text('채택'),
                  ),
                if (widget.isMine) ...[
                  IconButton(
                    key: const ValueKey('answer-edit'),
                    icon: const Icon(Icons.edit, size: 18),
                    tooltip: '수정',
                    visualDensity: VisualDensity.compact,
                    // 재조회로 본문이 바뀌어도 이미 초기화된 컨트롤러는 옛 텍스트를 쥔다 —
                    // 여는 순간 동기화한다(web 답변 카드와 같은 계약).
                    onPressed: widget.submitting
                        ? null
                        : () => setState(() {
                            _ctrl.text = widget.answer.bodyMd;
                            _editing = true;
                          }),
                  ),
                  IconButton(
                    key: const ValueKey('answer-delete'),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    tooltip: '삭제',
                    visualDensity: VisualDensity.compact,
                    onPressed: widget.submitting ? null : _confirmDelete,
                  ),
                ],
              ],
            ),
            const SizedBox(height: DpSpacing.xs),
            if (_editing)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    key: const ValueKey('answer-edit-field'),
                    controller: _ctrl,
                    minLines: 3,
                    maxLines: 8,
                    enabled: !widget.submitting,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: DpSpacing.xs),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        key: const ValueKey('answer-edit-cancel'),
                        onPressed: () => setState(() {
                          _editing = false;
                          _ctrl.text = answer.bodyMd;
                        }),
                        child: const Text('취소'),
                      ),
                      TextButton(
                        key: const ValueKey('answer-edit-save'),
                        onPressed: () {
                          widget.onSave(_ctrl.text);
                          setState(() => _editing = false);
                        },
                        child: const Text('저장'),
                      ),
                    ],
                  ),
                ],
              )
            else
              DpMarkdown(data: answer.bodyMd),
            const SizedBox(height: DpSpacing.xs),
            _VoteBar(
              upvotes: answer.upvoteCount,
              enabled: !widget.submitting,
              onVote: widget.onVote,
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
