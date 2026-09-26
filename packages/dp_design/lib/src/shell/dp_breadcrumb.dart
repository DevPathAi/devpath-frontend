import 'package:flutter/material.dart';

import '../theme/dp_colors.dart';
import '../theme/dp_spacing.dart';
import 'dp_chrome_bar.dart' show DpCrumb;

/// 본문 상단 브레드크럼(스펙 §5.3, 시안 `.crumb`).
///
/// `DpChromeBar` 안의 브레드크럼과 별개다 — 크롬바는 `apps/admin` 이 계속 쓰고,
/// web 은 크롬바 없이 이것을 본문 맨 위에 둔다.
class DpBreadcrumb extends StatelessWidget {
  const DpBreadcrumb({super.key, required this.crumbs, this.onCrumbTap});

  final List<DpCrumb> crumbs;
  final ValueChanged<String>? onCrumbTap;

  @override
  Widget build(BuildContext context) {
    if (crumbs.isEmpty) return const SizedBox.shrink();
    final c = context.dpColors;
    final style = Theme.of(
      context,
    ).textTheme.labelMedium?.copyWith(color: c.textFaint);

    final children = <Widget>[];
    for (var i = 0; i < crumbs.length; i++) {
      final crumb = crumbs[i];
      final isLast = i == crumbs.length - 1;
      final label = Text(
        crumb.label,
        style: style?.copyWith(color: isLast ? c.textFaint : c.textSecondary),
        overflow: TextOverflow.ellipsis,
      );

      children.add(
        // 마지막 세그먼트는 현재 위치이므로 path 가 있어도 링크하지 않는다.
        (crumb.path == null || isLast)
            ? ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: DpDensity.minTarget,
                ),
                child: Align(alignment: Alignment.centerLeft, child: label),
              )
            : Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => onCrumbTap?.call(crumb.path!),
                  borderRadius: BorderRadius.circular(DpRadius.button),
                  child: Container(
                    constraints: const BoxConstraints(
                      minHeight: DpDensity.minTarget,
                    ),
                    alignment: Alignment.centerLeft,
                    child: label,
                  ),
                ),
              ),
      );

      if (!isLast) {
        children.add(
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: DpDensity.minTarget),
            child: Align(
              alignment: Alignment.center,
              child: Text('›', style: style),
            ),
          ),
        );
      }
    }

    return Semantics(
      container: true,
      label: '현재 위치',
      child: Wrap(
        spacing: DpSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: children,
      ),
    );
  }
}
