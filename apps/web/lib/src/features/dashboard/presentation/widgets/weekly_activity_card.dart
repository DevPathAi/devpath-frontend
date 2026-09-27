import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// 주간 학습량 바차트(최근 7일 일별 완료 콘텐츠 수). fl_chart BarChart.
class WeeklyActivityCard extends StatelessWidget {
  const WeeklyActivityCard({super.key, required this.activity});

  final List<DailyActivity> activity;

  static const _weekdayLabels = ['월', '화', '수', '목', '금', '토', '일'];

  @override
  Widget build(BuildContext context) {
    final c = context.dpColors;
    final text = Theme.of(context).textTheme;
    final hasData = activity.any((a) => a.completedCount > 0);
    // 시안 `.panel` — 자체 `BoxDecoration` 대신 `DpPanel`(테두리 한 겹·반경 8·
    // 그림자 없음)을 쓰고 제목은 패널 제목행으로 올린다. 키는 옮겨 붙인다.
    return DpPanel(
      key: const Key('weekly-activity-card'),
      title: const DpPanelTitle('주간 학습량'),
      padding: const EdgeInsets.all(DpSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
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
    final maxCount = activity
        .map((a) => a.completedCount)
        .fold(0, (a, b) => a > b ? a : b);
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: (maxCount + 1).toDouble(),
        barTouchData: BarTouchData(enabled: true),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          show: true,
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                final label = (i >= 0 && i < activity.length)
                    ? _weekdayLabels[DateTime.parse(activity[i].date).weekday -
                          1]
                    : '';
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < activity.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: activity[i].completedCount.toDouble(),
                  color: c.chart1,
                  width: 14,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
