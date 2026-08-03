import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 완료된 경로: 멘토 rationale + 이번 주 과제 + 12주 타임라인.
class PathPlanView extends StatelessWidget {
  const PathPlanView({super.key, required this.plan});
  final LearningPath plan;

  @override
  Widget build(BuildContext context) {
    final c = context.dpColors;
    final text = Theme.of(context).textTheme;
    final thisWeek = plan.milestones.isNotEmpty ? plan.milestones.first : null;
    final diagnosis = plan.diagnosis;

    return ListView(
      padding: const EdgeInsets.all(DpSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.all(DpSpacing.md),
          decoration: BoxDecoration(
            color: c.surface,
            border: Border.all(color: c.border),
            borderRadius: BorderRadius.circular(DpRadius.card),
          ),
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
          Text('진단 요약', style: text.titleMedium),
          const SizedBox(height: DpSpacing.sm),
          Text('현재 수준 ${diagnosis.diagnosedLevel}', style: text.bodyMedium),
          // 색만으로 강점/약점을 구분하지 않는다(DESIGN.md §1) — 소제목 텍스트를
          // 병행하고, 약점은 "위험"이 아니므로 중립(textSecondary)을 쓴다.
          if (diagnosis.strengthConcepts.isNotEmpty) ...[
            const SizedBox(height: DpSpacing.sm),
            Text('강점', style: text.titleSmall),
            const SizedBox(height: DpSpacing.xs),
            Wrap(
              spacing: DpSpacing.xs,
              runSpacing: DpSpacing.xs,
              children: [
                for (final strength in diagnosis.strengthConcepts)
                  _Tag(label: strength, color: c.success),
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
                  _Tag(label: weakness, color: c.textSecondary),
              ],
            ),
          ],
        ],
        if (thisWeek != null) ...[
          const SizedBox(height: DpSpacing.xl),
          Text('이번 주 과제', style: text.titleMedium),
          const SizedBox(height: DpSpacing.sm),
          Text(thisWeek.expectedOutcome, style: text.bodySmall),
          const SizedBox(height: DpSpacing.sm),
          for (final t in thisWeek.tasks) _TaskTile(task: t),
        ],
        const SizedBox(height: DpSpacing.xl),
        Text('12주 타임라인', style: text.titleMedium),
        const SizedBox(height: DpSpacing.sm),
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
    );
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

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(DpRadius.chip),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DpSpacing.xs,
          vertical: 2,
        ),
        child: Text(label, style: text.labelSmall),
      ),
    );
  }
}
