import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// 마일스톤(주차)별 완료율 막대차트.
///
/// 마일스톤을 **계열이 아니라 X축**으로 둔다 — 12주를 색으로 구분하는 것은
/// 불가능하기 때문이다(3-B 스펙 §2.1). 단일 계열이라 범례를 두지 않는다.
/// `/paths/current`가 주는 데이터만 쓰므로 백엔드 확장이 필요 없다.
class MilestoneProgressCard extends StatelessWidget {
  const MilestoneProgressCard({super.key, required this.milestones});

  final List<PathMilestone> milestones;

  @override
  Widget build(BuildContext context) {
    final c = context.dpColors;
    final text = Theme.of(context).textTheme;
    return Container(
      key: const Key('milestone-progress-card'),
      padding: const EdgeInsets.all(DpSpacing.lg),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(context.appTokens.panelRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('주차별 진행률', style: text.titleMedium),
          const SizedBox(height: DpSpacing.sm),
          if (milestones.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: DpSpacing.lg),
              child: Text(
                '아직 학습 경로가 없어요',
                style: text.bodyMedium?.copyWith(color: c.textSecondary),
              ),
            )
          else
            SizedBox(height: 140, child: _chart(context)),
        ],
      ),
    );
  }

  /// 과제가 없는 주차는 0%다(나눗셈을 하지 않는다).
  double _percentOf(PathMilestone m) {
    if (m.tasks.isEmpty) return 0;
    final done = m.tasks.where((t) => t.completed).length;
    return done * 100.0 / m.tasks.length;
  }

  Widget _chart(BuildContext context) {
    final c = context.dpColors;
    return BarChart(
      BarChartData(
        minY: 0,
        maxY: 100,
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(),
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= milestones.length) {
                  return const SizedBox.shrink();
                }
                return Text(
                  '${milestones[i].weekNum}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: c.textSecondary),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < milestones.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: _percentOf(milestones[i]),
                  color: c.chart1,
                  width: 10,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(2),
                  ),
                  // 경로를 막 만든 사용자는 12주가 전부 0%다. 막대만 그리면 높이 0이라
                  // 화면에 아무것도 남지 않아 「차트가 고장났다」로 읽힌다. 도넛이
                  // 미완료를 면으로 그리는 것과 같은 원칙으로 트랙을 깐다(스펙 §4).
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: 100,
                    color: c.surfaceMuted,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
