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
    final thisWeek = plan.weeks.isNotEmpty ? plan.weeks.first : null;

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
        if (thisWeek != null) ...[
          const SizedBox(height: DpSpacing.xl),
          Text('이번 주 과제', style: text.titleMedium),
          const SizedBox(height: DpSpacing.sm),
          for (final t in thisWeek.tasks)
            ListTile(
              dense: true,
              leading: Icon(
                t.done ? DpIcons.stepDone : DpIcons.stepPending,
                color: t.done ? c.success : c.textSecondary,
              ),
              title: Text(t.title, style: text.bodyMedium),
            ),
        ],
        const SizedBox(height: DpSpacing.xl),
        Text('12주 타임라인', style: text.titleMedium),
        const SizedBox(height: DpSpacing.sm),
        for (final w in plan.weeks)
          ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 14,
              backgroundColor: c.primary,
              child: Text(
                '${w.week}',
                style: text.labelLarge?.copyWith(color: c.onPrimary),
              ),
            ),
            title: Text(w.title, style: text.bodyMedium),
          ),
      ],
    );
  }
}
