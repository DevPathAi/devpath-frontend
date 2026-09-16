import 'package:flutter/material.dart';

import '../theme/dp_colors.dart';
import '../theme/dp_spacing.dart';
import '../theme/dp_tokens.dart';

/// 인라인 알림의 의미 톤. 색은 [DpColors] 의 danger/warning/primary 를 따른다.
enum DpInlineNoticeTone { danger, warning, info }

/// 이미 그린 데이터를 유지한 채 보여주는 인라인 알림(부분 실패·저장 실패·경고).
///
/// 전체 화면 상태(`DpError`/`DpEmpty`)와 달리 콘텐츠 흐름 안에 놓이며,
/// 스크린리더는 liveRegion 으로 메시지를 읽는다. 행동은 [actionLabel] 이 있을 때
/// 하나만 렌더되고, [onAction] 이 null 이면 비활성이다(제출 중 등).
class DpInlineNotice extends StatelessWidget {
  const DpInlineNotice({
    super.key,
    required this.message,
    this.tone = DpInlineNoticeTone.danger,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final DpInlineNoticeTone tone;
  final String? actionLabel;
  final VoidCallback? onAction;

  static const double _stackBelowWidth = 520;

  @override
  Widget build(BuildContext context) {
    final colors = context.dpColors;
    final accent = switch (tone) {
      DpInlineNoticeTone.danger => colors.danger,
      DpInlineNoticeTone.warning => colors.warning,
      DpInlineNoticeTone.info => colors.primary,
    };
    final text = Text(
      message,
      style: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(color: colors.textPrimary),
    );
    final action = actionLabel == null
        ? null
        : TextButton(onPressed: onAction, child: Text(actionLabel!));

    return Semantics(
      key: const ValueKey('dp-inline-notice'),
      liveRegion: true,
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.08),
          border: Border.all(color: accent.withValues(alpha: 0.35)),
          borderRadius: BorderRadius.circular(context.appTokens.panelRadius),
        ),
        child: Padding(
          padding: const EdgeInsets.all(DpSpacing.md),
          child: action == null
              ? text
              : LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth < _stackBelowWidth) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          text,
                          const SizedBox(height: DpSpacing.xs),
                          Align(
                            alignment: Alignment.centerRight,
                            child: action,
                          ),
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: text),
                        const SizedBox(width: DpSpacing.sm),
                        action,
                      ],
                    );
                  },
                ),
        ),
      ),
    );
  }
}
