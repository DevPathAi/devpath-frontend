import 'package:flutter/material.dart';

import '../layout/dp_max_width.dart';
import '../theme/dp_colors.dart';
import '../theme/dp_spacing.dart';
import 'dp_breadcrumb.dart';
import 'dp_chrome_bar.dart' show DpCrumb;
import 'dp_menu_button.dart';
import 'dp_rail_brand.dart';
import 'dp_web_footer.dart';
import 'dp_web_header.dart';
import 'dp_web_nav_item.dart';

/// 웹 문법 셸(스펙 §5.3·§7 P2, 시안 `.screen`): 상단 헤더 + 중앙 본문 + 푸터.
///
/// `DpAppShell`(레일 + 크롬바 + 하단 내비)을 **대체하지 않는다** — 그쪽은
/// `apps/admin` 이 계속 쓴다. 이것은 `apps/web` 전용이다.
///
/// 본문은 폭과 무관하게 항상 `contentMaxWidth` 로 중앙 정렬한다
/// (`DpAppShell.constrainBodyAtLarge` 와 다른 규칙 — 시안 `.main` 은 무조건이다).
class DpWebShell extends StatelessWidget {
  const DpWebShell({
    super.key,
    required this.brand,
    required this.items,
    required this.selectedId,
    required this.onSelect,
    required this.accountEntries,
    required this.footerNotice,
    required this.footerLinks,
    required this.body,
    this.breadcrumb = const [],
    this.onCrumbTap,
    this.onSearchTap,
  });

  final DpRailBrand brand;
  final List<DpWebNavItem> items;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  final List<DpMenuEntry> accountEntries;
  final String footerNotice;
  final List<DpFooterLink> footerLinks;
  final Widget body;
  final List<DpCrumb> breadcrumb;
  final ValueChanged<String>? onCrumbTap;
  final VoidCallback? onSearchTap;

  @override
  Widget build(BuildContext context) {
    final c = context.dpColors;
    final compact =
        MediaQuery.sizeOf(context).width < DpWebHeader.compactBreakpoint;

    return Scaffold(
      backgroundColor: c.bg,
      // `DpAppShell` 이 갖고 있던 정책을 그대로 승계한다. 빼면 기본
      // `ReadingOrderTraversalPolicy` 가 위치로 정렬해 **화면 안** Tab 순서가
      // 바뀐다(2026-09-26 CI 실측: 커뮤니티에서 '글 작성' 이 목록 행 뒤로 밀렸다).
      // P2 는 셸을 바꾸는 단계지 화면의 순회 순서를 바꾸는 단계가 아니다.
      body: FocusTraversalGroup(
        policy: WidgetOrderTraversalPolicy(),
        child: Column(
          children: [
            DpWebHeader(
              brand: brand,
              items: items,
              selectedId: selectedId,
              onSelect: onSelect,
              accountEntries: accountEntries,
              onSearchTap: onSearchTap,
            ),
            Expanded(
              child: Padding(
                key: const ValueKey('web-shell-main'),
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? DpSpacing.lg : DpSpacing.xl,
                ),
                child: DpMaxWidth(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DpBreadcrumb(crumbs: breadcrumb, onCrumbTap: onCrumbTap),
                      Expanded(child: body),
                    ],
                  ),
                ),
              ),
            ),
            DpWebFooter(notice: footerNotice, links: footerLinks),
          ],
        ),
      ),
    );
  }
}
