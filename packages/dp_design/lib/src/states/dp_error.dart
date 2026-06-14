import 'package:flutter/material.dart';

import '../icons/dp_icons.dart';
import '../theme/dp_colors.dart';
import 'dp_state_scaffold.dart';

class DpError extends StatelessWidget {
  const DpError({
    super.key,
    required this.message,
    this.onRetry,
    this.title = '문제가 발생했어요',
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => DpStateScaffold(
        icon: DpIcons.error,
        iconColor: context.dpColors.danger,
        title: title,
        message: message,
        actionLabel: onRetry == null ? null : '다시 시도',
        onAction: onRetry,
      );
}
