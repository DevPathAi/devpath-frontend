import 'package:flutter/material.dart';

import '../theme/dp_colors.dart';
import '../theme/dp_spacing.dart';

/// 상태 화면 공통 레이아웃: 아이콘 + 제목 + (메시지) + (단일 1차 행동) + (선택 보조 행동).
///
/// 1차 행동은 여전히 **하나**다. 보조 행동은 1차와 경쟁하지 않도록 TextButton 으로,
/// 1차 아래에 둔다(예: 오류 화면의 [다시 시도] 밑 [문의하기]).
class DpStateScaffold extends StatelessWidget {
  const DpStateScaffold({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.iconColor,
    this.secondaryActionLabel,
    this.onSecondaryAction,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? iconColor;

  /// 보조 행동 라벨. [onSecondaryAction] 과 **둘 다** 있어야 렌더된다.
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    final c = context.dpColors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DpSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: iconColor ?? c.textSecondary),
            const SizedBox(height: DpSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (message != null) ...[
              const SizedBox(height: DpSpacing.sm),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: c.textSecondary),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: DpSpacing.lg),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
            if (secondaryActionLabel != null && onSecondaryAction != null) ...[
              SizedBox(
                height: (actionLabel != null && onAction != null)
                    ? DpSpacing.xs
                    : DpSpacing.lg,
              ),
              TextButton(
                onPressed: onSecondaryAction,
                child: Text(secondaryActionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
