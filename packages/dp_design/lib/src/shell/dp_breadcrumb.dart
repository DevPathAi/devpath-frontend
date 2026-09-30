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
/// `·` 인 상태)에서도 같은 요청이 그대로 났다. 그 요청은 이 위젯과 무관했다:
/// 원인은 `ChipThemeData.labelStyle` 에 `fontFamily` 가 없어 칩 라벨만 번들에
/// 없는 패밀리로 그려진 것이었다(2026-09-26 실측, `DpTheme` 에서 수정).
class DpBreadcrumb extends StatelessWidget {
  const DpBreadcrumb({super.key, required this.crumbs, this.onCrumbTap});

  final List<DpCrumb> crumbs;
  final ValueChanged<String>? onCrumbTap;

  @override
  Widget build(BuildContext context) {
    if (crumbs.isEmpty) return const SizedBox.shrink();
    final c = context.dpColors;
    // compact 에서는 마지막 세그먼트만 — `DpChromeBar._crumbs` 와 같은 규칙이다.
    // 전체 경로를 폰 폭에 욱여넣으면 잘려서 어차피 읽을 수 없다.
    // (이 규칙을 폰트 폭주의 해법으로 적어 뒀던 앞선 기록은 틀렸다 — 폭주의
    //  원인은 칩 라벨 스타일이었고, 생략기호 `…` 는 번들 폰트에 있다.)
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
