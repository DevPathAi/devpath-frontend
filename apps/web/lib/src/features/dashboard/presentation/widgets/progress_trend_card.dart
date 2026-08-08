import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// 계열 정의 — **키는 서버 enum 원문이라 불변**이고 라벨만 표시용이다.
/// 순서가 곧 chart1·chart2·chart3 배정 순서다.
const _series = <({String key, String label})>[
  (key: 'READ', label: '읽기'),
  (key: 'PRACTICE', label: '실습'),
  (key: 'QUIZ', label: '퀴즈'),
];

/// 진행률 추이 라인차트(최근 14일 누적 완료율 %). 과제 유형별 다중 계열.
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
          else ...[
            SizedBox(height: 140, child: _chart(context)),
            if (_activeSeries().isNotEmpty) ...[
              const SizedBox(height: DpSpacing.sm),
              DpChartLegend(
                items: [
                  for (final s in _activeSeries())
                    (color: _colorOf(context, s), label: s.label),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  /// 히스토리에 실제로 존재하는 계열만 고른다 — 과제가 없는 유형은 키 자체가 없다.
  List<({String key, String label})> _activeSeries() {
    if (history.isEmpty) return const [];
    final keys = history.first.byType.keys.toSet();
    return _series.where((s) => keys.contains(s.key)).toList();
  }

  Color _colorOf(BuildContext context, ({String key, String label}) s) {
    final c = context.dpColors;
    final palette = [c.chart1, c.chart2, c.chart3];
    return palette[_series.indexOf(s) % palette.length];
  }

  Widget _chart(BuildContext context) {
    final c = context.dpColors;
    final active = _activeSeries();
    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 100,
        lineTouchData: const LineTouchData(enabled: true),
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        titlesData: const FlTitlesData(show: false),
        lineBarsData: active.isEmpty
            // byType이 비면(옛 응답) 전체 누적률 1선으로 떨어진다.
            ? [
                _bar([
                  for (var i = 0; i < history.length; i++)
                    FlSpot(i.toDouble(), history[i].percent.toDouble()),
                ], c.chart1),
              ]
            : [
                for (final s in active)
                  _bar([
                    for (var i = 0; i < history.length; i++)
                      FlSpot(
                        i.toDouble(),
                        (history[i].byType[s.key] ?? 0).toDouble(),
                      ),
                  ], _colorOf(context, s)),
              ],
      ),
    );
  }

  /// 채움(belowBarData)은 쓰지 않는다 — 반투명 면이 여러 장 겹치면 색이 섞여
  /// 계열 판별이 오히려 나빠진다(3-B 스펙 §4).
  LineChartBarData _bar(List<FlSpot> spots, Color color) => LineChartBarData(
    spots: spots,
    isCurved: true,
    color: color,
    barWidth: 3,
    dotData: const FlDotData(show: false),
  );
}
