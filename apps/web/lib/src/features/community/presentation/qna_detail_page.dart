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
import 'widgets/content_tombstone.dart';
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
              onSave: (body) => notifier.updateAnswer(a.id, body),
              onChanged: () => notifier.load(detail.id),
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

/// 답변 카드. 수정은 화면 전환 없이 **카드 안에서** 연다 — 짧은 글에 페이지 전환은 과하다.
/// 리치 에디터가 아니라 TextField 다: 카드마다 툴바를 띄우면 레이아웃이 흔들린다.
class _AnswerCard extends StatefulWidget {
  const _AnswerCard({
    required this.answer,
    required this.questionSolved,
    required this.submitting,
    required this.currentUserId,
    required this.onVote,
    required this.onAccept,
    required this.onSave,
    required this.onChanged,
  });

  final CommunityAnswer answer;
  final bool questionSolved;
  final bool submitting;
  final String? currentUserId;
  final ValueChanged<int> onVote;
  final VoidCallback onAccept;

  /// 인라인 편집 저장. 카드는 서버를 직접 부르지 않고 컨트롤러에 위임한다.
  final ValueChanged<String> onSave;

  /// 삭제 성공 뒤 — 상세 재조회를 호출자가 맡는다.
  final VoidCallback onChanged;

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

  @override
  Widget build(BuildContext context) {
    final answer = widget.answer;
    if (answer.deleted) return const ContentTombstone();
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
                // AI 초안은 authorId 가 null 이라 「남의 것」으로 분류돼 신고만 보인다.
                ContentMenuButton(
                  kind: ContentKind.answer,
                  targetId: answer.id,
                  authorId: answer.authorId,
                  currentUserId: widget.currentUserId,
                  // 재조회로 본문이 바뀌어도 이미 초기화된 컨트롤러는 옛 텍스트를 쥔다 —
                  // 여는 순간 동기화해 옛 본문으로 최신을 덮는 사고를 막는다.
                  onEdit: () => setState(() {
                    _ctrl.text = widget.answer.bodyMd;
                    _editing = true;
                  }),
                  onDeleted: widget.onChanged,
                ),
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
                          final body = _ctrl.text.trim();
                          if (body.isEmpty) {
                            // 컨트롤러는 빈 본문을 서버에 안 보낸다(왕복 낭비). 그 침묵을
                            // 사용자에게는 스펙의 400 문구로 표면화하고 에디터를 유지한다.
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('내용을 입력해 주세요')),
                            );
                            return;
                          }
                          widget.onSave(body);
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
