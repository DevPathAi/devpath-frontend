import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'milestone_progress_card.dart';

/// 완료된 경로: 멘토 rationale + 이번 주 과제 + 12주 타임라인.
class PathPlanView extends StatelessWidget {
  const PathPlanView({super.key, required this.plan});
  final LearningPath plan;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(DpSpacing.lg),
    children: children(context, plan),
  );

  /// 문서형 화면(sliver) 배선용 — 이 위젯 자체(내부 [ListView])를 쓰지 않고,
  /// 호출부의 CustomScrollView에 직접 [SliverList]로 실을 수 있도록 콘텐츠만
  /// 노출한다. 중첩 스크롤(헤더가 사라지지 않는 결함)을 피하기 위함이다.
  static List<Widget> children(BuildContext context, LearningPath plan) {
    final c = context.dpColors;
    final text = Theme.of(context).textTheme;
    final thisWeek = plan.milestones.isNotEmpty ? plan.milestones.first : null;
    final diagnosis = plan.diagnosis;

    return [
      DpPanel(
        padding: const EdgeInsets.all(DpSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(DpIcons.mentor, size: 18, color: c.primaryText),
            const SizedBox(width: DpSpacing.sm),
            Expanded(
              child: Text(
                plan.rationale,
                style: text.bodyMedium?.copyWith(color: c.textSecondary),
              ),
            ),
          ],
        ),
      ),
      if (diagnosis != null) ...[
        const SizedBox(height: DpSpacing.xl),
        DpPanel(
          title: const DpPanelTitle('진단 요약'),
          padding: const EdgeInsets.all(DpSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('현재 수준 ${diagnosis.diagnosedLevel}', style: text.bodyMedium),
              // 색만으로 강점/약점을 구분하지 않는다(DESIGN.md §1) — 소제목
              // 텍스트가 구분을 지고, 칩은 `DpTag` 의 중립 토큰을 쓴다.
              if (diagnosis.strengthConcepts.isNotEmpty) ...[
                const SizedBox(height: DpSpacing.sm),
                Text('강점', style: text.titleSmall),
                const SizedBox(height: DpSpacing.xs),
                Wrap(
                  spacing: DpSpacing.xs,
                  runSpacing: DpSpacing.xs,
                  children: [
                    for (final strength in diagnosis.strengthConcepts)
                      DpTag(label: strength),
                  ],
                ),
              ],
              if (diagnosis.weaknessConcepts.isNotEmpty) ...[
                const SizedBox(height: DpSpacing.sm),
                Text('보강할 점', style: text.titleSmall),
                const SizedBox(height: DpSpacing.xs),
                Wrap(
                  spacing: DpSpacing.xs,
                  runSpacing: DpSpacing.xs,
                  children: [
                    for (final weakness in diagnosis.weaknessConcepts)
                      DpTag(label: weakness),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
      if (thisWeek != null) ...[
        const SizedBox(height: DpSpacing.xl),
        DpPanel(
          title: const DpPanelTitle('이번 주 과제'),
          // `DpPanel` 은 색을 가진 `DecoratedBox` 다 — 그 안의 Material
          // `ListTile` 은 가장 가까운 Material(Scaffold) 에 잉크를 그리므로
          // 패널 표면에 가려진다(프레임워크가 단언으로 잡는다). 패널 안쪽에
          // 투명 Material 을 한 겹 둬 잉크가 패널 위에 오게 한다.
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    DpSpacing.lg,
                    DpSpacing.md,
                    DpSpacing.lg,
                    0,
                  ),
                  child: Text(thisWeek.expectedOutcome, style: text.bodySmall),
                ),
                for (final t in thisWeek.tasks) _TaskTile(task: t),
              ],
            ),
          ),
        ),
      ],
      // 「이번 주」에서 「전체 주차」로 시야가 넓어지는 순서로 둔다.
      const SizedBox(height: DpSpacing.xl),
      MilestoneProgressCard(milestones: plan.milestones),
      const SizedBox(height: DpSpacing.xl),
      DpPanel(
        title: const DpPanelTitle('12주 타임라인'),
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final m in plan.milestones)
                ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 14,
                    backgroundColor: m.locked ? c.surface : c.primary,
                    child: Text(
                      '${m.weekNum}',
                      style: text.labelLarge?.copyWith(
                        color: m.locked ? c.textSecondary : c.onPrimary,
                      ),
                    ),
                  ),
                  title: Text(m.title, style: text.bodyMedium),
                  subtitle: Text(
                    '${m.goalDescription}\n${m.whyThisOrder}',
                    style: text.bodySmall?.copyWith(color: c.textSecondary),
                  ),
                ),
            ],
          ),
        ),
      ),
    ];
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({required this.task});

  final WeeklyTask task;

  @override
  Widget build(BuildContext context) {
    final c = context.dpColors;
    final text = Theme.of(context).textTheme;
    final target = task.contentSlug ?? task.contentId?.toString();

    return ListTile(
      dense: true,
      enabled: target != null,
      onTap: target == null ? null : () => context.go('/content/$target'),
      leading: Icon(
        task.completed ? DpIcons.stepDone : DpIcons.stepPending,
        color: task.completed ? c.success : c.textSecondary,
      ),
      title: Text(task.title, style: text.bodyMedium),
      subtitle: Text(
        '${task.taskType}${task.required ? ' · 필수' : ''}',
        style: text.bodySmall?.copyWith(color: c.textSecondary),
      ),
    );
  }
}
