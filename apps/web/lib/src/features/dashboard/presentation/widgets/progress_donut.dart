import 'package:dp_design/dp_design.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// 전체 진행률 도넛(fl_chart PieChart). 중앙 퍼센트 라벨 + 섹션 hover 툴팁.
class ProgressDonut extends StatelessWidget {
  const ProgressDonut({super.key, required this.percent});

  /// 0~100.
  final int percent;

  @override
  Widget build(BuildContext context) {
    final c = context.dpColors;
    final p = percent.clamp(0, 100).toDouble();
    return Semantics(
      label: '전체 진행률 $percent 퍼센트',
      child: SizedBox(
        height: 132,
        width: 132,
        child: Stack(
          alignment: Alignment.center,
          children: [
            PieChart(
              PieChartData(
                startDegreeOffset: 270,
                sectionsSpace: 0,
                centerSpaceRadius: 46,
                pieTouchData: PieTouchData(enabled: true),
                sections: [
                  PieChartSectionData(
                    value: p,
                    color: c.chart1,
                    radius: 12,
                    showTitle: false,
                  ),
                  PieChartSectionData(
                    value: 100 - p,
                    // 미완료는 **면**이다 — 경계선 토큰(border)을 면에 쓰던 오용을
                    // 면 토큰으로 바로잡는다(3-B 스펙 §4).
                    color: c.surfaceMuted,
                    radius: 12,
                    showTitle: false,
                  ),
                ],
              ),
            ),
            Text(
              '$percent%',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(color: c.primaryText),
            ),
          ],
        ),
      ),
    );
  }
}
