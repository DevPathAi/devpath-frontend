import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';

/// 시안 `content` 의 `.side` 「콘텐츠 학습 진행률」.
///
/// 본문 위에 있던 `LinearProgressIndicator` + `'$percent% 진행'` 과 같은
/// 데이터다 — 위치만 옮긴다. 서버로 보내는 진행률 계산(`_scrollPct`)과는
/// 무관하다(그쪽은 스크롤 위치로 잰다).
class ContentProgressPanel extends StatelessWidget {
  const ContentProgressPanel({super.key, required this.content});

  final LearningContent content;

  @override
  Widget build(BuildContext context) {
    final c = context.dpColors;
    final progress = content.progress;
    final percent = (progress.scrollPct * 100).round().clamp(0, 100);

    return DpPanel(
      title: const DpPanelTitle('콘텐츠 학습 진행률'),
      padding: const EdgeInsets.symmetric(
        vertical: DpSpacing.md,
        horizontal: DpSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          LinearProgressIndicator(
            value: progress.scrollPct.clamp(0, 1).toDouble(),
          ),
          const SizedBox(height: DpSpacing.sm),
          Text(
            progress.completed
                ? '완료 · 끝까지 읽어 완료로 저장됐어요'
                : '$percent% · 끝까지 읽으면 완료로 저장됩니다',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: c.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// 시안 `content` 의 `.side` 「현재 학습 미션」 — 이번 주 과제 셋과 현재 위치.
///
/// 지금 읽는 과제와 이미 완료한 과제는 링크로 만들지 않는다 — 전자는 갈 곳이
/// 지금 이 화면이고, 후자는 목록의 맥락 표시일 뿐이다.
class ContentMissionPanel extends StatelessWidget {
  const ContentMissionPanel({
    super.key,
    required this.mission,
    required this.currentTaskId,
    required this.onOpenTask,
  });

  final CurrentMission? mission;
  final int? currentTaskId;
  final ValueChanged<WeeklyTask> onOpenTask;

  @override
  Widget build(BuildContext context) {
    final tasks = mission?.tasks ?? const <WeeklyTask>[];
    if (tasks.isEmpty) return const SizedBox.shrink();

    return DpPanel(
      title: const DpPanelTitle('현재 학습 미션'),
      child: DpListLines(
        children: [
          for (final task in tasks)
            Row(
              children: [
                _mark(task),
                const SizedBox(width: DpSpacing.sm),
                Expanded(
                  child: task.taskId == currentTaskId || task.completed
                      ? Text(task.title)
                      : DpLink.inline(
                          text: task.title,
                          onTap: () => onOpenTask(task),
                        ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _mark(WeeklyTask task) {
    if (task.completed) {
      return const DpStatusText(text: '✓', tone: DpStatusTone.done);
    }
    if (task.taskId == currentTaskId) {
      return const DpStatusText(text: '●', tone: DpStatusTone.current);
    }
    return const DpStatusText(text: '·', tone: DpStatusTone.idle);
  }
}
