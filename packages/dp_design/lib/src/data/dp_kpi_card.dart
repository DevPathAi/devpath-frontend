import 'package:flutter/material.dart';

import '../theme/dp_colors.dart';
import '../theme/dp_spacing.dart';
import '../theme/dp_tokens.dart';

/// KPI 단일 지표 카드(Layer 2). 숫자 카운트업 + 라벨 + 옵셔널 아이콘/진행바.
/// go_router·Riverpod 비의존 순수 표현부. 색·반경·간격은 토큰만 사용.
class DpKpiCard extends StatelessWidget {
  const DpKpiCard({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.suffix,
    this.progress,
    this.countUpDuration = DpDurations.stageReveal,
  });

  final String label;
  final int value;
  final IconData? icon;
  final String? suffix;

  /// 0~1 목표 진행바(옵셔널). 데이터 없으면 미지정 → 진행바 미표시.
  final double? progress;
  final Duration countUpDuration;

  @override
  Widget build(BuildContext context) {
    final c = context.dpColors;
    final text = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: '$label $value${suffix ?? ''}',
      child: Container(
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
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20, color: c.primary),
                  const SizedBox(width: DpSpacing.xs),
                ],
                Text(
                  label,
                  style: text.titleSmall?.copyWith(color: c.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: DpSpacing.sm),
            TweenAnimationBuilder<int>(
              duration: countUpDuration,
              tween: IntTween(begin: 0, end: value),
              builder: (_, v, _) => Text(
                '$v${suffix ?? ''}',
                style: text.displaySmall?.copyWith(color: c.primaryText),
              ),
            ),
            if (progress != null) ...[
              const SizedBox(height: DpSpacing.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(DpRadius.button),
                child: LinearProgressIndicator(value: progress),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
