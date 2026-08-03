import 'package:flutter/material.dart';

import '../icons/dp_icons.dart';
import '../theme/dp_colors.dart';
import '../theme/dp_spacing.dart';
import '../theme/dp_tokens.dart';
import 'dp_destination.dart';

/// 잉크 사이드바(로드맵 Layer 2). 라우팅 비의존 — 선택은 index로 통지.
///
/// 섹션은 평면 [destinations]에서 연속된 같은 [DpDestination.section]끼리
/// 묶어 렌더한다. 접힘 상태에서는 레이블 대신 구분선을 넣는다.
class DpNavRail extends StatelessWidget {
  const DpNavRail({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelect,
    this.brand,
    this.account,
    this.extended = true,
    this.onToggle,
  });

  final List<DpDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final Widget? brand;
  final Widget? account;
  final bool extended;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final c = context.dpColors;
    final t = context.appTokens;
    final width = extended ? t.railWidth : t.railCollapsedWidth;

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: c.railBg,
        border: Border(right: BorderSide(color: c.railBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (brand != null || onToggle != null) _buildTop(context, c),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: _buildItems(context, c),
            ),
          ),
          if (account != null) ...[
            Divider(height: 1, thickness: 1, color: c.railBorder),
            Padding(
              padding: const EdgeInsets.all(DpSpacing.sm),
              child: account,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTop(BuildContext context, DpColors c) => Padding(
    padding: const EdgeInsets.fromLTRB(
      DpSpacing.md,
      DpSpacing.md,
      DpSpacing.sm,
      DpSpacing.sm,
    ),
    child: Row(
      children: [
        if (extended && brand != null) Expanded(child: brand!),
        if (onToggle != null)
          IconButton(
            icon: Icon(
              extended ? DpIcons.menuOpen : DpIcons.menu,
              color: c.railMuted,
            ),
            tooltip: extended ? '메뉴 접기' : '메뉴 펼치기',
            onPressed: onToggle,
          ),
      ],
    ),
  );

  List<Widget> _buildItems(BuildContext context, DpColors c) {
    final text = Theme.of(context).textTheme;
    final out = <Widget>[];
    String? lastSection;

    for (var i = 0; i < destinations.length; i++) {
      final d = destinations[i];
      if (d.section != null && d.section != lastSection) {
        out.add(
          extended
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(
                    DpSpacing.lg,
                    DpSpacing.md,
                    DpSpacing.lg,
                    DpSpacing.xs,
                  ),
                  child: Text(
                    d.section!,
                    style: text.labelMedium?.copyWith(
                      color: c.railFaint,
                      letterSpacing: 0.8,
                    ),
                  ),
                )
              : Padding(
                  key: const ValueKey('rail-section-divider'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: DpSpacing.md,
                    vertical: DpSpacing.sm,
                  ),
                  child: Divider(height: 1, thickness: 1, color: c.railBorder),
                ),
        );
      }
      lastSection = d.section;
      out.add(_item(context, c, d, i));
    }
    return out;
  }

  Widget _item(BuildContext context, DpColors c, DpDestination d, int i) {
    final selected = i == selectedIndex;
    final text = Theme.of(context).textTheme;
    final icon = d.badgeCount > 0
        ? Badge(
            label: Text('${d.badgeCount}'),
            child: Icon(
              d.icon,
              size: 20,
              color: selected ? c.railText : c.railMuted,
            ),
          )
        : Icon(d.icon, size: 20, color: selected ? c.railText : c.railMuted);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DpSpacing.sm,
        vertical: 1,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onSelect(i),
          borderRadius: BorderRadius.circular(DpRadius.button),
          child: Container(
            key: ValueKey('rail-item-$i'),
            decoration: BoxDecoration(
              color: selected ? c.railActive : Colors.transparent,
              borderRadius: BorderRadius.circular(DpRadius.button),
              border: selected
                  ? Border(left: BorderSide(color: c.primary, width: 2))
                  : null,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: DpSpacing.sm,
              vertical: DpSpacing.sm,
            ),
            child: Row(
              mainAxisAlignment: extended
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                icon,
                if (extended) ...[
                  const SizedBox(width: DpSpacing.md),
                  Expanded(
                    child: Text(
                      d.label,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall?.copyWith(
                        color: selected ? c.railText : c.railMuted,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
