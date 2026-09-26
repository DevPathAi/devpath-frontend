import 'package:flutter/material.dart';

import '../theme/dp_colors.dart';
import '../theme/dp_spacing.dart';
import 'dp_chrome_bar.dart' show DpCrumb;

/// 본문 상단 브레드크럼(스펙 §5.3, 시안 `.crumb`).
///
/// `DpChromeBar` 안의 브레드크럼과 별개다 — 크롬바는 `apps/admin` 이 계속 쓰고,
/// web 은 크롬바 없이 이것을 본문 맨 위에 둔다.
///
/// **구분자는 `·` 다. 시안의 `›`(U+203A) 로 되돌리지 말 것** — 번들 폰트에 없어
/// CanvasKit 이 fonts.gstatic.com 에서 Noto Sans Symbols 를 받아 온다. 실측
/// (CI 36212413896 vs develop 35932928056): develop 에 없던 `notosanssymbols`
/// 요청이 이 브랜치에서만 생겼고, 외부 요청이 차단된 browser-ux 에서
/// `/content` 가 390x200% 에서 networkidle 에 도달하지 못했다. 운영에서도
/// 페이지마다 폰트를 한 벌 더 받는다(docs/design/font-diet.md 의 방향과 반대).
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
        // `widthFactor: 1` 이 없으면 Align 이 Wrap 의 최대 폭까지 늘어나 세그먼트가
        // 줄마다 쌓인다(실측: 3세그먼트 높이 120px, 구분자가 혼자 떠 있었다).
        (crumb.path == null || isLast)
            ? ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: DpDensity.minTarget,
                ),
                child: Center(widthFactor: 1, child: label),
              )
            : Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => onCrumbTap?.call(crumb.path!),
                  borderRadius: BorderRadius.circular(DpRadius.button),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: DpDensity.minTarget,
                    ),
                    child: Center(widthFactor: 1, child: label),
                  ),
                ),
              ),
      );

      if (!isLast) {
        children.add(
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: DpDensity.minTarget),
            child: Center(widthFactor: 1, child: Text('·', style: style)),
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
