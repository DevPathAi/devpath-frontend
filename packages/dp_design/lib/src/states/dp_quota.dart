import 'package:flutter/material.dart';

import '../icons/dp_icons.dart';
import '../theme/dp_colors.dart';
import 'dp_state_scaffold.dart';

/// QUOTA_EXCEEDED(429) — 한도 + Retry-After 정적 표시 + 업그레이드 안내.
/// [retryAfterSeconds]가 null(헤더 미제공)이거나 음수(시계 오차)면 0초/음수 오안내 없이
/// 무기한 문구로 분기한다(F6-b). 양수면 "약 N초 후" 정적 표시(카운트다운 아님 — F6-d).
class DpQuota extends StatelessWidget {
  const DpQuota({super.key, required this.retryAfterSeconds, this.onUpgrade});
  final int? retryAfterSeconds;
  final VoidCallback? onUpgrade;

  @override
  Widget build(BuildContext context) {
    final s = retryAfterSeconds;
    final message = (s == null || s < 0)
        ? '잠시 후 다시 시도해 주세요.'
        : '약 $s초 후 다시 시도할 수 있어요.';
    return DpStateScaffold(
      icon: DpIcons.quota,
      iconColor: context.dpColors.warning,
      title: '오늘 사용 한도에 도달했어요',
      message: message,
      actionLabel: onUpgrade == null ? null : '플랜 업그레이드',
      onAction: onUpgrade,
    );
  }
}
