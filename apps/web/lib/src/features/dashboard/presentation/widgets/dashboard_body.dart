import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';

import '../../../ads/presentation/ad_slot_widget.dart';
import 'progress_donut.dart';

/// 대시보드 성공 상태 본문. 폭별 Bento(staggered) 재배치.
class DashboardBody extends StatelessWidget {
  const DashboardBody({super.key, required this.summary});
  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final cross = switch (context.windowClass) {
      DpWindowClass.compact => 1,
      DpWindowClass.medium => 2,
      _ => 4, // expanded/large: 4열 Bento
    };
    final maxW = context.appTokens.contentMaxWidth;

    // 셀 폭 배분(cross열 기준): CTA는 넓게, KPI는 1열, 도넛/배지는 폭별 조정.
    final ctaSpan = cross >= 4 ? 2 : cross;
    final donutSpan = cross >= 4 ? 2 : (cross == 2 ? 2 : 1);
    final badgeSpan = cross;

    final tiles = <StaggeredGridTile>[
      StaggeredGridTile.fit(
        crossAxisCellCount: cross,
        child: const AdSlotWidget(slot: 'DASHBOARD_TOP'),
      ),
      StaggeredGridTile.fit(
        crossAxisCellCount: ctaSpan,
        child: _HeroCta(title: summary.nextTaskTitle),
      ),
      StaggeredGridTile.fit(
        crossAxisCellCount: 1,
        child: DpKpiCard(
          label: '연속 학습',
          value: summary.streakDays,
          suffix: '일',
          icon: DpIcons.stepDone,
        ),
      ),
      StaggeredGridTile.fit(
        crossAxisCellCount: 1,
        child: DpKpiCard(
          label: '완료 콘텐츠',
          value: summary.completedContentCount,
          icon: DpIcons.content,
        ),
      ),
      StaggeredGridTile.fit(
        crossAxisCellCount: donutSpan,
        child: _DonutCard(percent: summary.progressPercent),
      ),
      if (summary.badges.isNotEmpty)
        StaggeredGridTile.fit(
          crossAxisCellCount: badgeSpan,
          child: _BadgeStrip(badges: summary.badges),
        ),
    ];

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(DpSpacing.lg),
          child: StaggeredGrid.count(
            crossAxisCount: cross,
            mainAxisSpacing: DpSpacing.md,
            crossAxisSpacing: DpSpacing.md,
            children: tiles,
          ),
        ),
      ),
    );
  }
}

Widget _panel(BuildContext context, Widget child) {
  final c = context.dpColors;
  return Container(
    padding: const EdgeInsets.all(DpSpacing.lg),
    decoration: BoxDecoration(
      color: c.surface,
      border: Border.all(color: c.border),
      borderRadius: BorderRadius.circular(context.appTokens.panelRadius),
    ),
    child: child,
  );
}

class _HeroCta extends StatelessWidget {
  const _HeroCta({required this.title});
  final String? title;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final c = context.dpColors;
    return _panel(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('다음 과제', style: text.titleMedium),
          const SizedBox(height: DpSpacing.xs),
          Text(
            title ?? '경로를 생성해 보세요',
            style: text.bodyMedium?.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: DpSpacing.md),
          FilledButton(
            onPressed: () => context.go('/path'),
            child: const Text('이어서 학습'),
          ),
        ],
      ),
    );
  }
}

class _DonutCard extends StatelessWidget {
  const _DonutCard({required this.percent});
  final int percent;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return _panel(
      context,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('전체 진행률', style: text.titleMedium),
          const SizedBox(height: DpSpacing.sm),
          Center(child: ProgressDonut(percent: percent)),
        ],
      ),
    );
  }
}

class _BadgeStrip extends StatelessWidget {
  const _BadgeStrip({required this.badges});
  final List<String> badges;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return _panel(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('배지', style: text.titleMedium),
          const SizedBox(height: DpSpacing.sm),
          Wrap(
            spacing: DpSpacing.sm,
            runSpacing: DpSpacing.xs,
            children: [for (final b in badges) Chip(label: Text(b))],
          ),
        ],
      ),
    );
  }
}
