import 'package:flutter/material.dart';

import '../theme/dp_colors.dart';
import '../theme/dp_spacing.dart';

/// 차트 계열 범례(Layer 2). 색 견본 + 라벨을 나란히 놓고 좁은 폭에서 줄바꿈한다.
///
/// **입력은 레코드 리스트 하나뿐이다 — Widget 슬롯을 받지 않는다.** 앱이 스타일을
/// 실을 통로를 애초에 만들지 않는다(3-A `DpRailBrand`에서 같은 함정을 타입으로 닫았다).
class DpChartLegend extends StatelessWidget {
  const DpChartLegend({super.key, required this.items});

  final List<({Color color, String label})> items;

  @override
  Widget build(BuildContext context) {
    final c = context.dpColors;
    final text = Theme.of(context).textTheme;
    return Wrap(
      spacing: DpSpacing.md,
      runSpacing: DpSpacing.xs,
      children: [
        for (final it in items)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                key: const ValueKey('dp-chart-legend-swatch'),
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: it.color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: DpSpacing.xs),
              Text(
                it.label,
                style: text.bodySmall?.copyWith(color: c.textSecondary),
              ),
            ],
          ),
      ],
    );
  }
}
