import 'package:flutter/material.dart';

import '../icons/dp_icons.dart';
import '../theme/dp_colors.dart';
import '../theme/dp_spacing.dart';
import '../theme/dp_tokens.dart';
import 'dp_destination.dart';
import 'dp_rail_brand.dart';

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

  /// null이면 어떤 항목도 활성 표시하지 않는다(호출부 위치가 레일 목적지
  /// 어디에도 매칭되지 않는 경우 — I1: 잘못된 항목을 강조하는 대신 무강조).
  final int? selectedIndex;
  final ValueChanged<int> onSelect;
  final DpRailBrand? brand;
  final Widget? account;
  final bool extended;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final c = context.dpColors;
    final t = context.appTokens;
    final width = extended ? t.railWidth : t.railCollapsedWidth;

    return Container(
      key: const ValueKey('rail-root'),
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
              child: _withRailForeground(c.railMuted, account!),
            ),
          ],
        ],
      ),
    );
  }

  /// [child]가 명시적으로 색을 주지 않았을 때만 적용되는 기본 전경색.
  /// 다크 레일 배경 위에서 무스타일 텍스트/아이콘이 [DpTheme]의 본문
  /// 색(라이트 테마 기준 textPrimary)으로 렌더돼 배경과 구별 불가능해지는
  /// 결함을 막는다 — 하위 위젯이 색을 명시하면 그게 이긴다(merge).
  static Widget _withRailForeground(Color color, Widget child) =>
      IconTheme.merge(
        data: IconThemeData(color: color),
        child: DefaultTextStyle.merge(
          style: TextStyle(color: color),
          child: child,
        ),
      );

  Widget _buildTop(BuildContext context, DpColors c) {
    final b = brand;
    final text = Theme.of(context).textTheme;

    final toggleButton = onToggle == null
        ? null
        : IconButton(
            icon: Icon(
              extended ? DpIcons.menuOpen : DpIcons.menu,
              color: c.railMuted,
            ),
            tooltip: extended ? '메뉴 접기' : '메뉴 펼치기',
            onPressed: onToggle,
          );

    // 접힘 + 마크 + 토글은 가로로 나란히 놓을 자리가 없다: railCollapsedWidth
    // (72) - 좌우 패딩(md+sm=20) = 가용 52px인데 mark(22) + IconButton(Material
    // 최소 탭 타깃 48) = 70px이 필요해 19px RenderFlex 오버플로가 난다(실측,
    // dp_nav_rail_test.dart의 red-repro). 44px 최소 탭 타깃(DD7)을 지키며
    // 마크를 지우지 않는 조합이 이 폭에서 존재하지 않으므로(44+8=52가 이론
    // 한계, 8px 마크는 무의미), 접힘 상태에서만 마크 위에 토글을 세로로
    // 쌓는다 — 브랜드가 먼저 읽혀야 하므로 마크가 위. **이 분기를 가로
    // Row로 되돌리지 말 것** — 위 수치대로 다시 오버플로한다.
    if (!extended && b != null && toggleButton != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DpSpacing.sm,
          vertical: DpSpacing.sm,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [b.mark, toggleButton],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DpSpacing.md,
        DpSpacing.md,
        DpSpacing.sm,
        DpSpacing.sm,
      ),
      child: Row(
        children: [
          if (b != null) ...[
            // 마크는 접힘에서도 남는다 — 2단계에서는 extended 조건 안에
            // 함께 묶여 있어 접히면 브랜드가 통째로 사라졌다.
            b.mark,
            if (extended) ...[
              const SizedBox(width: DpSpacing.sm),
              // Expanded(flex 참여)로 감싼다 — non-flex Text는 무한 주축
              // 제약으로 측정되어 ellipsis가 발동하지 않는다.
              Expanded(
                child: Text(
                  b.wordmark,
                  overflow: TextOverflow.ellipsis,
                  // 색을 여기서 확정한다. 앱은 문자열만 주므로 이 색이
                  // merge에서 질 상대가 없다.
                  style: text.titleSmall?.copyWith(color: c.railText),
                ),
              ),
            ],
          ],
          ?toggleButton,
        ],
      ),
    );
  }

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
    final iconGlyph = Icon(
      d.icon,
      size: 20,
      color: selected ? c.railText : c.railMuted,
    );
    final icon = d.badgeCount > 0
        ? Badge(label: Text('${d.badgeCount}'), child: iconGlyph)
        : iconGlyph;

    final content = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onSelect(i),
        borderRadius: BorderRadius.circular(DpRadius.button),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
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

    // 스크린리더·키보드 사용자를 위해 목적지/선택 상태를 프로그램적으로 노출한다.
    final withSemantics = Semantics(
      key: ValueKey('rail-item-semantics-$i'),
      button: true,
      label: d.label,
      selected: selected,
      child: content,
    );

    // 접힘 상태는 라벨 텍스트가 안 보이므로 hover 대체 수단으로 툴팁을 단다.
    // 펼침 상태는 라벨이 이미 보이므로 툴팁이 불필요하다.
    final withTooltip = extended
        ? withSemantics
        : Tooltip(message: d.label, child: withSemantics);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DpSpacing.sm,
        vertical: 1,
      ),
      child: withTooltip,
    );
  }
}
