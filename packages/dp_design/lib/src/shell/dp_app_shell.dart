import 'package:flutter/material.dart';

import '../icons/dp_icons.dart';
import '../layout/dp_max_width.dart';
import '../layout/dp_window_class.dart';
import '../theme/dp_spacing.dart';
import '../theme/dp_tokens.dart';
import 'dp_destination.dart';

/// 4-클래스 반응형 앱 셸(로드맵 §2.2 Layer 2). 라우팅 비의존 —
/// 목적지 선택은 [onSelect]에 index로 통지, 경로 해석은 앱이 담당.
class DpAppShell extends StatelessWidget {
  const DpAppShell({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelect,
    required this.body,
    this.leading,
    this.trailing,
    this.accountSlot,
    this.railExtended,
    this.onToggleRail,
    this.constrainBodyAtLarge = true,
  });

  final List<DpDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final Widget body;
  final Widget? leading;
  final Widget? trailing;
  final Widget? accountSlot;
  final bool? railExtended;
  final VoidCallback? onToggleRail;
  final bool constrainBodyAtLarge;

  static Widget _icon(DpDestination d) => d.badgeCount > 0
      ? Badge(label: Text('${d.badgeCount}'), child: Icon(d.icon))
      : Icon(d.icon);

  @override
  Widget build(BuildContext context) {
    final wc = context.windowClass;

    if (wc == DpWindowClass.compact) {
      return Scaffold(
        body: body,
        bottomNavigationBar: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: onSelect,
          destinations: [
            for (final d in destinations)
              NavigationDestination(icon: _icon(d), label: d.label),
          ],
        ),
      );
    }

    // medium 기본 접힘, expanded/large 기본 펼침. railExtended가 오버라이드.
    final extended = railExtended ?? (wc != DpWindowClass.medium);
    final content = (constrainBodyAtLarge && wc == DpWindowClass.large)
        ? DpMaxWidth(child: body)
        : body;

    return Scaffold(
      body: FocusTraversalGroup(
        child: Row(
          children: [
            NavigationRail(
              extended: extended,
              minExtendedWidth: context.appTokens.railWidth,
              labelType: extended ? null : NavigationRailLabelType.none,
              selectedIndex: selectedIndex,
              onDestinationSelected: onSelect,
              leading: _buildLeading(extended),
              trailing: _buildTrailing(),
              destinations: [
                for (final d in destinations)
                  NavigationRailDestination(
                    icon: _icon(d),
                    label: Text(d.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: content),
          ],
        ),
      ),
    );
  }

  Widget? _buildLeading(bool extended) {
    final items = <Widget>[
      ?leading,
      if (onToggleRail != null)
        IconButton(
          icon: Icon(extended ? DpIcons.menuOpen : DpIcons.menu),
          tooltip: extended ? '메뉴 접기' : '메뉴 펼치기',
          onPressed: onToggleRail,
        ),
    ];
    if (items.isEmpty) return null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DpSpacing.sm),
      child: Column(mainAxisSize: MainAxisSize.min, children: items),
    );
  }

  Widget? _buildTrailing() {
    final items = <Widget>[?trailing, ?accountSlot];
    if (items.isEmpty) return null;
    return Expanded(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.only(bottom: DpSpacing.md),
          child: Column(mainAxisSize: MainAxisSize.min, children: items),
        ),
      ),
    );
  }
}
