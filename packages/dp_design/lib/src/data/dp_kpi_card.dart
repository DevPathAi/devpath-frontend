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
        // KPI 그리드는 200% 텍스트에서도 고정 extent 안에 들어가야 한다.
        // 외곽 리듬은 lg로 유지하고 아이콘 surface로 시각적 밀도를 보강한다.
        padding: const EdgeInsets.all(DpSpacing.lg),
        decoration: BoxDecoration(
          color: c.surface,
          border: Border.all(color: c.border),
          borderRadius: BorderRadius.circular(context.appTokens.panelRadius),
          boxShadow: [
            BoxShadow(
              color: c.textPrimary.withValues(alpha: 0.035),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: c.accentSoft,
                      borderRadius: BorderRadius.circular(DpRadius.button),
                    ),
                    child: Icon(icon, size: 20, color: c.primaryText),
                  ),
                  const SizedBox(width: DpSpacing.md),
                ],
                Text(
                  label,
                  style: text.titleSmall?.copyWith(color: c.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: DpSpacing.md),
            TweenAnimationBuilder<int>(
              duration: countUpDuration,
              tween: IntTween(begin: 0, end: value),
              builder: (_, v, _) => Text(
                '$v${suffix ?? ''}',
                style: text.displaySmall?.copyWith(
                  color: c.textPrimary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1,
                ),
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
