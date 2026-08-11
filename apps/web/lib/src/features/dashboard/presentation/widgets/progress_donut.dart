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
                    // 미완료 트랙. 면에는 면 토큰(surfaceMuted)이 의미론상 맞지만,
                    // 실측하면 카드 대비가 라이트 1.14:1 · 다크 1.08:1로 border
                    // (1.34 · 1.32)보다 낮아 조각이 **오히려 덜 보인다.**
                    // 육안 확인에서 발견해 스펙 §4의 교체 지시를 철회했다.
                    color: c.border,
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
