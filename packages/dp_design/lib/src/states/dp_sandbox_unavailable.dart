import 'package:flutter/material.dart';

import '../icons/dp_icons.dart';
import '../theme/dp_colors.dart';
import 'dp_state_scaffold.dart';

/// SANDBOX_UNAVAILABLE(503) — 실행만 비활성, 코드 편집은 유지(안내 배너).
class DpSandboxUnavailable extends StatelessWidget {
  const DpSandboxUnavailable({super.key, this.onDismiss});
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) => DpStateScaffold(
    icon: DpIcons.sandboxOff,
    iconColor: context.dpColors.warning,
    title: '지금은 코드를 실행할 수 없어요',
    message: '편집은 계속할 수 있어요. 잠시 후 실행을 다시 시도해 주세요.',
    actionLabel: onDismiss == null ? null : '확인',
    onAction: onDismiss,
  );
}
