import 'package:flutter/material.dart';

import '../icons/dp_icons.dart';
import '../theme/dp_colors.dart';
import 'dp_state_scaffold.dart';

/// QUOTA_EXCEEDED(429) — 한도 + Retry-After 카운트 + 업그레이드 안내.
class DpQuota extends StatelessWidget {
  const DpQuota({super.key, required this.retryAfterSeconds, this.onUpgrade});
  final int retryAfterSeconds;
  final VoidCallback? onUpgrade;

  @override
  Widget build(BuildContext context) => DpStateScaffold(
        icon: DpIcons.quota,
        iconColor: context.dpColors.warning,
        title: '오늘 사용 한도에 도달했어요',
        message: '약 $retryAfterSeconds초 후 다시 시도할 수 있어요.',
        actionLabel: onUpgrade == null ? null : '플랜 업그레이드',
        onAction: onUpgrade,
      );
}
