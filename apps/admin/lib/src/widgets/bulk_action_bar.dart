import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';

/// 다중 선택 시 등장하는 벌크 액션바(admin 공용).
class BulkActionBar extends StatelessWidget {
  const BulkActionBar({
    super.key,
    required this.count,
    required this.actionLabel,
    required this.onAction,
    required this.onClear,
  });

  final int count;
  final String actionLabel;
  final VoidCallback onAction;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final c = context.dpColors;
    return Material(
      color: c.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DpSpacing.lg,
          vertical: DpSpacing.sm,
        ),
        child: Row(
          children: [
            Text('선택 $count개', style: Theme.of(context).textTheme.titleSmall),
            const Spacer(),
            TextButton(onPressed: onClear, child: const Text('선택 해제')),
            const SizedBox(width: DpSpacing.sm),
            FilledButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}
