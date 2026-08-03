import 'package:flutter/material.dart';

import '../theme/dp_colors.dart';
import '../theme/dp_spacing.dart';

/// 본문 최상단 페이지 헤더(로드맵 Layer 2).
///
/// 제목은 **기존 headlineSmall(24/32 w600)** 을 쓴다. 새 타입 스케일을
/// 만들면 Material 기본값으로 떨어져 한글 행간 1.6이 빠진다.
class DpPageHeader extends StatelessWidget {
  const DpPageHeader({
    super.key,
    required this.title,
    this.description,
    this.actions = const [],
    this.filters,
  });

  final String title;
  final String? description;
  final List<Widget> actions;
  final Widget? filters;

  @override
  Widget build(BuildContext context) {
    final c = context.dpColors;
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DpSpacing.lg,
        DpSpacing.lg,
        DpSpacing.lg,
        DpSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        title,
                        style: text.headlineSmall?.copyWith(
                          color: c.textPrimary,
                        ),
                      ),
                    ),
                    if (description != null) ...[
                      const SizedBox(height: DpSpacing.xs),
                      Text(
                        description!,
                        key: const ValueKey('page-header-description'),
                        style: text.bodySmall?.copyWith(color: c.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
              if (actions.isNotEmpty) ...[
                const SizedBox(width: DpSpacing.md),
                Flexible(
                  child: Wrap(
                    spacing: DpSpacing.sm,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: actions,
                  ),
                ),
              ],
            ],
          ),
          if (filters != null) ...[
            const SizedBox(height: DpSpacing.md),
            KeyedSubtree(
              key: const ValueKey('page-header-filters'),
              child: filters!,
            ),
          ],
        ],
      ),
    );
  }
}
