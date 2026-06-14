import 'package:flutter/material.dart';

import '../theme/dp_colors.dart';
import '../theme/dp_spacing.dart';

/// 상태 화면 공통 레이아웃: 아이콘 + 제목 + (메시지) + (단일 1차 행동).
class DpStateScaffold extends StatelessWidget {
  const DpStateScaffold({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? iconColor;

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
            Text(title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium),
            if (message != null) ...[
              const SizedBox(height: DpSpacing.sm),
              Text(message!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: c.textSecondary)),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: DpSpacing.lg),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
