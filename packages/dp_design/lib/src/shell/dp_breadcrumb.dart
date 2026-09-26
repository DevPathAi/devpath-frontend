import 'package:flutter/material.dart';

import '../theme/dp_colors.dart';
import '../theme/dp_spacing.dart';
import 'dp_chrome_bar.dart' show DpCrumb;

/// 본문 상단 브레드크럼(스펙 §5.3, 시안 `.crumb`).
///
/// `DpChromeBar` 안의 브레드크럼과 별개다 — 크롬바는 `apps/admin` 이 계속 쓰고,
/// web 은 크롬바 없이 이것을 본문 맨 위에 둔다.
///
/// 구분자는 시안대로 `›` 다. 한때 `·` 로 바꿨다가 되돌렸다 — `notosanssymbols`
/// 폰트 폴백 요청이 이 글자 때문이라고 봤는데, 실측(CI 36214032743, 구분자가
/// `·` 인 상태)에서도 같은 요청이 그대로 났다. 그 요청은 원인이 아니라 390x200%
/// 에서 `/content` 가 안 가라앉는 것의 **증상**이다(두 실행 모두 그 시나리오
/// 에서만 나타난다).
class DpBreadcrumb extends StatelessWidget {
  const DpBreadcrumb({super.key, required this.crumbs, this.onCrumbTap});

  final List<DpCrumb> crumbs;
  final ValueChanged<String>? onCrumbTap;

  @override
  Widget build(BuildContext context) {
    if (crumbs.isEmpty) return const SizedBox.shrink();
    final c = context.dpColors;
    // compact 에서는 마지막 세그먼트만 — `DpChromeBar._crumbs` 와 같은 규칙이다.
    // 전체 경로를 폰 폭에 욱여넣으면 잘리고, 잘린 자리에 그려지는 ellipsis(…)가
    // 번들 폰트에 없어 CanvasKit 이 Noto Sans Symbols 를 계속 다시 받는다
    // (CI 36215681312 실측: 390x200% 에서 차단된 요청 724건 중 695건이 그 폰트).
    final visible = MediaQuery.sizeOf(context).width < 600
        ? [crumbs.last]
        : crumbs;
    final style = Theme.of(
      context,
    ).textTheme.labelMedium?.copyWith(color: c.textFaint);

    final children = <Widget>[];
    for (var i = 0; i < visible.length; i++) {
      final crumb = visible[i];
      final isLast = i == visible.length - 1;
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
            child: Center(widthFactor: 1, child: Text('›', style: style)),
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
