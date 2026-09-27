import 'package:flutter/material.dart';

import '../theme/dp_colors.dart';
import '../theme/dp_spacing.dart';
import 'dp_window_class.dart';

/// 본문 최상단 페이지 헤더(로드맵 Layer 2).
///
/// 모바일에서는 제목과 행동을 한 열로, 넓은 화면에서는 한 행으로 배치한다.
class DpPageHeader extends StatelessWidget {
  const DpPageHeader({
    super.key,
    required this.title,
    this.description,
    this.actions = const [],
    this.filters = const [],
  });

  final String title;
  final String? description;
  final List<Widget> actions;

  /// 헤더 아래 필터 줄. 자식들은 Wrap의 형제로 배치되어 좁은 폭에서
  /// 줄바꿈한다 — Row를 통째로 받으면 줄바꿈이 일어나지 않는다.
  final List<Widget> filters;

  @override
  Widget build(BuildContext context) {
    final c = context.dpColors;
    final text = Theme.of(context).textTheme;
    final compact = context.windowClass == DpWindowClass.compact;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        compact ? DpSpacing.lg : DpSpacing.xl,
        compact ? DpSpacing.xl : DpSpacing.xxl,
        compact ? DpSpacing.lg : DpSpacing.xl,
        DpSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final titleBlock = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      title,
                      style: text.headlineSmall?.copyWith(color: c.textPrimary),
                    ),
                  ),
                  if (description != null) ...[
                    const SizedBox(height: DpSpacing.sm),
                    Text(
                      description!,
                      key: const ValueKey('page-header-description'),
                      style: text.bodyMedium?.copyWith(color: c.textSecondary),
                    ),
                  ],
                ],
              );
              final actionBlock = Wrap(
                spacing: DpSpacing.sm,
                runSpacing: DpSpacing.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: actions,
              );

              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    titleBlock,
                    if (actions.isNotEmpty) ...[
                      const SizedBox(height: DpSpacing.lg),
                      actionBlock,
                    ],
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: titleBlock),
                  if (actions.isNotEmpty) ...[
                    const SizedBox(width: DpSpacing.xl),
                    ConstrainedBox(
                      constraints: constraints.hasBoundedWidth
                          ? BoxConstraints(maxWidth: constraints.maxWidth / 2)
                          : const BoxConstraints(),
                      child: actionBlock,
                    ),
                  ],
                ],
              );
            },
          ),
          if (filters.isNotEmpty) ...[
            const SizedBox(height: DpSpacing.md),
            KeyedSubtree(
              key: const ValueKey('page-header-filters'),
              child: Wrap(
                spacing: DpSpacing.sm,
                runSpacing: DpSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: filters,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
