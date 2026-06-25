import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/mentor_controller.dart';
import '../state/mentor_state.dart';

const _kExamples = ['비동기란?', '테스트는 어떻게 작성하나요?', 'Riverpod이 뭔가요?'];

class MentorPage extends ConsumerStatefulWidget {
  const MentorPage({super.key});

  @override
  ConsumerState<MentorPage> createState() => _MentorPageState();
}

class _MentorPageState extends ConsumerState<MentorPage> {
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _send(String q) {
    _input.clear();
    ref.read(mentorControllerProvider.notifier).send(q);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(mentorControllerProvider);
    final c = context.dpColors;

    return Scaffold(
      appBar: AppBar(title: const Text('AI 멘토')),
      body: Column(
        children: [
          if (s.status == MentorStatus.killSwitch)
            const DpKillSwitch()
          else
            Expanded(
              child: s.messages.isEmpty
                  ? _Empty(onPick: _send)
                  : ListView.builder(
                      padding: const EdgeInsets.all(DpSpacing.lg),
                      itemCount: s.messages.length,
                      // ENG-REVIEW F9: 각 버블에 ValueKey 부여 + 스트리밍 중(마지막) 버블만
                      // 변하는 텍스트를 들고 갱신. 토큰당 visible 버블 전체 재빌드 방지 —
                      // 완료된 앞쪽 버블은 동일 Key·동일 text라 element 재사용(rebuild 스킵).
                      itemBuilder: (_, i) {
                        final isStreamingTail =
                            i == s.messages.length - 1 &&
                            s.status == MentorStatus.streaming;
                        return _Bubble(
                          key: ValueKey('msg-$i-${s.messages[i].fromUser}'),
                          message: s.messages[i],
                          // 스트리밍 꼬리만 텍스트가 자주 바뀜을 명시(앞쪽은 안정).
                          isStreamingTail: isStreamingTail,
                        );
                      },
                    ),
            ),
          // ENG-REVIEW D2: 끊김(partial) → 부분답변 보존 안내 + "다시 시도"(재전송) 버튼.
          if (s.status == MentorStatus.partial)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DpSpacing.lg,
                vertical: DpSpacing.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      s.error ?? '연결이 끊겼어요. 부분답변을 받았어요.',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: c.warning),
                    ),
                  ),
                  const SizedBox(width: DpSpacing.sm),
                  TextButton(
                    onPressed: () =>
                        ref.read(mentorControllerProvider.notifier).retry(),
                    child: const Text('다시 시도'),
                  ),
                ],
              ),
            ),
          if (s.status == MentorStatus.failed && s.error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: DpSpacing.lg),
              child: Text(
                s.error!,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: c.danger),
              ),
            ),
          // 슬라이스 #7 M-2: 참고자료(event:references) — 있으면 칩으로 렌더, 없으면 미표시.
          if (s.references.isNotEmpty)
            _ReferencePanel(references: s.references),
          if (s.status != MentorStatus.killSwitch)
            _Composer(controller: _input, onSend: _send),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onPick});
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const DpEmpty(
          icon: DpIcons.mentor,
          title: '첫 질문을 해보세요',
          message: '학습 중 막힌 부분을 물어보세요.',
        ),
        Wrap(
          spacing: DpSpacing.sm,
          children: [
            for (final e in _kExamples)
              ActionChip(label: Text(e), onPressed: () => onPick(e)),
          ],
        ),
      ],
    ),
  );
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    super.key,
    required this.message,
    this.isStreamingTail = false,
  });
  final ChatMessage message;

  /// 스트리밍 중인 마지막 멘토 버블 여부(F9: 자주 갱신되는 유일한 버블).
  final bool isStreamingTail;

  @override
  Widget build(BuildContext context) {
    final c = context.dpColors;
    final align = message.fromUser
        ? Alignment.centerRight
        : Alignment.centerLeft;
    final bg = message.fromUser ? c.primary : c.surface;
    final fg = message.fromUser ? c.onPrimary : c.textPrimary;
    final showTyping = !message.fromUser && message.text.isEmpty;

    return Align(
      alignment: align,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: DpSpacing.xs),
        padding: const EdgeInsets.all(DpSpacing.md),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: c.border),
          borderRadius: BorderRadius.circular(DpRadius.card),
        ),
        child: showTyping
            ? const SizedBox(
                width: 24,
                height: 12,
                child: LinearProgressIndicator(),
              ) // 타이핑 인디케이터
            : Text(
                message.text,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: fg),
              ),
      ),
    );
  }
}

/// 참고자료 패널(슬라이스 #7 M-2). `event:references`로 받은 콘텐츠 링크를
/// 칩으로 렌더한다. 비어 있으면 호출부에서 미표시.
class _ReferencePanel extends StatelessWidget {
  const _ReferencePanel({required this.references});
  final List<MentorReference> references;

  @override
  Widget build(BuildContext context) {
    final c = context.dpColors;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DpSpacing.lg,
        vertical: DpSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '참고자료',
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: DpSpacing.xs),
          Wrap(
            spacing: DpSpacing.sm,
            runSpacing: DpSpacing.xs,
            children: [
              for (final r in references)
                ActionChip(
                  key: ValueKey('ref-${r.contentId}'),
                  avatar: const Icon(DpIcons.content, size: 16),
                  label: Text(r.title),
                  onPressed: () => context.go('/content/${r.contentId}'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.onSend});
  final TextEditingController controller;
  final ValueChanged<String> onSend;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(DpSpacing.md),
    child: Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            onSubmitted: onSend,
            decoration: const InputDecoration(
              hintText: '질문을 입력하세요',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: DpSpacing.sm),
        IconButton.filled(
          tooltip: '전송',
          onPressed: () => onSend(controller.text),
          icon: const Icon(DpIcons.send),
        ),
      ],
    ),
  );
}
