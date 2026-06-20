import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';

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
        Text('학습 경로', style: text.headlineSmall),
        const SizedBox(height: DpSpacing.sm),
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
          const SizedBox(height: DpSpacing.xs),
          Wrap(
            spacing: DpSpacing.xs,
            runSpacing: DpSpacing.xs,
            children: [
              for (final strength in diagnosis.strengthConcepts)
                _Tag(label: strength, color: c.success),
              for (final weakness in diagnosis.weaknessConcepts)
                _Tag(label: weakness, color: c.warning),
            ],
          ),
        ],
        if (thisWeek != null) ...[
          const SizedBox(height: DpSpacing.xl),
          Text('이번 주 과제', style: text.titleMedium),
          const SizedBox(height: DpSpacing.sm),
          Text(thisWeek.expectedOutcome, style: text.bodySmall),
          const SizedBox(height: DpSpacing.sm),
          for (final t in thisWeek.tasks)
            ListTile(
              dense: true,
              leading: Icon(
                t.completed ? DpIcons.stepDone : DpIcons.stepPending,
                color: t.completed ? c.success : c.textSecondary,
              ),
              title: Text(t.title, style: text.bodyMedium),
              subtitle: Text(
                '${t.taskType}${t.required ? ' · 필수' : ''}',
                style: text.bodySmall?.copyWith(color: c.textSecondary),
              ),
            ),
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
