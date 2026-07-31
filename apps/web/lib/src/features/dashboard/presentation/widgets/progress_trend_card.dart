import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// 진행률 추이 라인차트(최근 14일 누적 완료율 %). fl_chart LineChart.
class ProgressTrendCard extends StatelessWidget {
  const ProgressTrendCard({super.key, required this.history});

  final List<ProgressPoint> history;

  @override
  Widget build(BuildContext context) {
    final c = context.dpColors;
    final text = Theme.of(context).textTheme;
    final hasData = history.isNotEmpty;
    return Container(
      key: const Key('progress-trend-card'),
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
          Text('진행률 추이', style: text.titleMedium),
          const SizedBox(height: DpSpacing.sm),
          if (!hasData)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: DpSpacing.lg),
              child: Text(
                '아직 학습 기록이 없어요',
                style: text.bodyMedium?.copyWith(color: c.textSecondary),
              ),
            )
          else
            SizedBox(height: 140, child: _chart(context)),
        ],
      ),
    );
  }

  Widget _chart(BuildContext context) {
    final c = context.dpColors;
    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 100,
        lineTouchData: const LineTouchData(enabled: true),
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        titlesData: const FlTitlesData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i < history.length; i++)
                FlSpot(i.toDouble(), history[i].percent.toDouble()),
            ],
            isCurved: true,
            color: c.primary,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: c.primary.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}
