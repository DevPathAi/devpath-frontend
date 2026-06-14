import 'package:flutter/material.dart';

import '../icons/dp_icons.dart';
import '../theme/dp_colors.dart';
import 'dp_state_scaffold.dart';

/// AI_KILL_SWITCH_ACTIVE(503) — '점검 중' + 대체 행동(캐시/커뮤니티/저장)으로 goodwill 보존(DD4).
class DpKillSwitch extends StatelessWidget {
  const DpKillSwitch({super.key, this.altActionLabel, this.onAltAction});
  final String? altActionLabel;
  final VoidCallback? onAltAction;

  @override
  Widget build(BuildContext context) => DpStateScaffold(
    icon: DpIcons.killSwitch,
    iconColor: context.dpColors.warning,
    title: 'AI 기능이 잠시 점검 중이에요',
    message: '곧 복구됩니다. 그동안 다른 학습을 이어가 보세요.',
    actionLabel: altActionLabel,
    onAction: onAltAction,
  );
}
