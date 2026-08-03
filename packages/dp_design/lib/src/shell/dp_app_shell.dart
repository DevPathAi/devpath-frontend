import 'package:flutter/material.dart';

import '../layout/dp_max_width.dart';
import '../layout/dp_window_class.dart';
import 'dp_chrome_bar.dart';
import 'dp_destination.dart';
import 'dp_nav_rail.dart';

/// 4-클래스 반응형 앱 셸(로드맵 §2.2 Layer 2). 라우팅 비의존 —
/// 목적지 선택은 [onSelect]에 index로 통지, 경로 해석은 앱이 담당.
///
/// 구조: [DpNavRail](세로) + [DpChromeBar](가로) + body.
/// [breadcrumb]이 비면 크롬바를 렌더하지 않는다.
/// [account]는 폭에 따라 레일 하단 또는 크롬바 우측으로 간다 —
/// 앱은 한 벌만 만들고 배치는 셸이 정한다.
class DpAppShell extends StatelessWidget {
  const DpAppShell({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelect,
    required this.body,
    this.brand,
    this.account,
    this.breadcrumb = const [],
    this.onCrumbTap,
    this.onSearchTap,
    this.chromeActions = const [],
    this.railExtended,
    this.onToggleRail,
    this.constrainBodyAtLarge = true,
  });

  final List<DpDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final Widget body;
  final Widget? brand;
  final Widget? account;
  final List<DpCrumb> breadcrumb;
  final ValueChanged<String>? onCrumbTap;
  final VoidCallback? onSearchTap;
  final List<Widget> chromeActions;
  final bool? railExtended;
  final VoidCallback? onToggleRail;
  final bool constrainBodyAtLarge;

  @override
  Widget build(BuildContext context) {
    final wc = context.windowClass;
    final compact = wc == DpWindowClass.compact;

    final content = (constrainBodyAtLarge && wc == DpWindowClass.large)
        ? DpMaxWidth(child: body)
        : body;

    // 크롬바에 실제로 전달될 게 있을 때만 렌더한다. account는 compact에서만
    // 크롬바로 가므로(그 외엔 레일로 간다) 그 경우만 여기 포함한다 — 안 그러면
    // compact + 빈 breadcrumb 조합에서 account·chromeActions가 어디에도
    // 도달하지 못하고 조용히 사라진다.
    final showChromeBar =
        breadcrumb.isNotEmpty ||
        chromeActions.isNotEmpty ||
        (compact && account != null);

    final main = Column(
      children: [
        if (showChromeBar)
          DpChromeBar(
            breadcrumb: breadcrumb,
            onCrumbTap: onCrumbTap,
            onSearchTap: onSearchTap,
            actions: chromeActions,
            account: compact ? account : null,
            compact: compact,
          ),
        Expanded(child: content),
      ],
    );

    if (compact) {
      return Scaffold(
        body: main,
        bottomNavigationBar: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: onSelect,
          destinations: [
            for (final d in destinations)
              NavigationDestination(
                icon: d.badgeCount > 0
                    ? Badge(label: Text('${d.badgeCount}'), child: Icon(d.icon))
                    : Icon(d.icon),
                label: d.label,
              ),
          ],
        ),
      );
    }

    // medium 기본 접힘, expanded/large 기본 펼침. railExtended가 오버라이드.
    final extended = railExtended ?? (wc != DpWindowClass.medium);

    return Scaffold(
      body: FocusTraversalGroup(
        child: Row(
          children: [
            DpNavRail(
              destinations: destinations,
              selectedIndex: selectedIndex,
              onSelect: onSelect,
              brand: brand,
              account: account,
              extended: extended,
              onToggle: onToggleRail,
            ),
            Expanded(child: main),
          ],
        ),
      ),
    );
  }
}
