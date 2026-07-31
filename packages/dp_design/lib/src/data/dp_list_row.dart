import 'package:flutter/material.dart';

import '../interaction/dp_interactive_card.dart';
import '../theme/dp_colors.dart';
import '../theme/dp_spacing.dart';

/// 리스트 행(Layer 2). 좌측 상태 표시선(accent) + 상단 뱃지행 → 제목 + 우측 trailing 메타.
/// DpInteractiveCard(hover/focus) 베이스. go_router·Riverpod 비의존 순수 표현부.
class DpListRow extends StatelessWidget {
  const DpListRow({
    super.key,
    required this.title,
    this.accentColor,
    this.badges = const [],
    this.trailing,
    this.onTap,
  });

  final String title;
  final Color? accentColor;
  final List<Widget> badges;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return DpInteractiveCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (accentColor != null)
              Container(
                width: 3,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(DpRadius.card),
                  ),
                ),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(DpSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (badges.isNotEmpty) ...[
                      Wrap(
                        spacing: DpSpacing.xs,
                        runSpacing: DpSpacing.xs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: badges,
                      ),
                      const SizedBox(height: DpSpacing.xs),
                    ],
                    Text(title, style: text.titleSmall),
                  ],
                ),
              ),
            ),
            if (trailing != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: DpSpacing.md,
                  vertical: DpSpacing.md,
                ),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: trailing,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
