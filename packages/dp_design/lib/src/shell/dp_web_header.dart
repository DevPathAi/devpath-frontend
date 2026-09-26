import 'package:flutter/material.dart';

import '../icons/dp_icons.dart';
import '../theme/dp_colors.dart';
import '../theme/dp_spacing.dart';
import '../theme/dp_tokens.dart';
import 'dp_menu_button.dart';
import 'dp_rail_brand.dart';
import 'dp_web_nav_item.dart';

/// 웹 문법의 상단 헤더(스펙 §5.3, 시안 `.hd`). 라우팅 비의존 — 선택은 id 로 통지.
///
/// 어두운 면(`headerBg`)이고 높이는 계약의 `AppTokens.headerHeight`(56)다.
/// [compactBreakpoint] 미만에서는 주 메뉴·검색·계정을 감추고 햄버거만 남기며,
/// 펼치면 헤더 **아래로 인라인 확장**한다 — overlay·drawer·focus trap 을 쓰지
/// 않는다(스펙 §5.3: 홈 랜딩과 같은 규칙).
class DpWebHeader extends StatefulWidget {
  const DpWebHeader({
    super.key,
    required this.brand,
    required this.items,
    required this.selectedId,
    required this.onSelect,
    required this.accountEntries,
    this.onSearchTap,
  });

  /// 시안 `@container (max-width:720px)`. `DpWindowClass` 경계(600/840)와 다르다 —
  /// 시안이 정한 값이라 그대로 쓴다.
  static const double compactBreakpoint = 720;

  final DpRailBrand brand;
  final List<DpWebNavItem> items;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  final List<DpMenuEntry> accountEntries;
  final VoidCallback? onSearchTap;

  @override
  State<DpWebHeader> createState() => _DpWebHeaderState();
}

class _DpWebHeaderState extends State<DpWebHeader> {
  final _burgerFocus = FocusNode(debugLabel: 'web-header-burger');
  bool _expanded = false;

  @override
  void dispose() {
    _burgerFocus.dispose();
    super.dispose();
  }

  void _pick(String id) {
    // 먼저 접는다 — 라우트가 바뀐 뒤에 접으면 새 화면 위에 메뉴가 남는다.
    if (_expanded) setState(() => _expanded = false);
    widget.onSelect(id);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dpColors;
    final compact =
        MediaQuery.sizeOf(context).width < DpWebHeader.compactBreakpoint;

    // Review Focus 1: compact 가 아니게 되면 접힘 상태를 자동으로 푼다.
    // 안 그러면 닫을 버튼(햄버거)이 사라진 채 메뉴만 남는다.
    if (!compact && _expanded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _expanded = false);
      });
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _bar(context, c, compact),
        if (compact && _expanded) _collapsedMenu(context, c),
      ],
    );
  }

  Widget _bar(BuildContext context, DpColors c, bool compact) => Container(
    key: const ValueKey('web-header-bar'),
    height: context.appTokens.headerHeight,
    decoration: BoxDecoration(
      color: c.headerBg,
      border: Border(bottom: BorderSide(color: c.headerBorder)),
    ),
    padding: EdgeInsets.symmetric(
      horizontal: compact ? DpSpacing.lg : DpSpacing.xl,
    ),
    child: Row(
      children: [
        _brand(context, c),
        if (compact) ...[
          const Spacer(),
          _burger(context, c),
        ] else ...[
          const SizedBox(width: DpSpacing.xl),
          Expanded(child: _nav(context, c)),
          const SizedBox(width: DpSpacing.xl),
          _search(context, c),
          const SizedBox(width: DpSpacing.sm),
          _account(context, c),
        ],
      ],
    ),
  );

  Widget _brand(BuildContext context, DpColors c) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox.square(
        dimension: 24,
        child: FittedBox(child: widget.brand.mark),
      ),
      const SizedBox(width: DpSpacing.sm),
      Text(
        widget.brand.wordmark,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: c.headerText,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
      ),
    ],
  );

  Widget _nav(BuildContext context, DpColors c) => Row(
    key: const ValueKey('web-header-nav'),
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final item in widget.items)
        Padding(
          padding: const EdgeInsets.only(right: DpSpacing.xs),
          child: item.children.isEmpty
              ? _navLink(context, c, item)
              : _navDropdown(context, c, item),
        ),
    ],
  );

  /// 평시 `headerMuted`, 현재 항목은 `headerText` + 하단 2px primary 밑줄(반경 0).
  Widget _navSurface(
    BuildContext context,
    DpColors c, {
    required DpWebNavItem item,
    required Widget child,
    required VoidCallback onTap,
    FocusNode? focusNode,
  }) {
    final current = item.isCurrent(widget.selectedId);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: current ? ValueKey('web-header-current-${item.id}') : null,
        focusNode: focusNode,
        onTap: onTap,
        borderRadius: current
            ? BorderRadius.zero
            : BorderRadius.circular(DpRadius.button),
        hoverColor: c.headerActive,
        child: Container(
          height: DpDensity.controlHeight,
          padding: const EdgeInsets.symmetric(horizontal: DpSpacing.md),
          decoration: current
              ? BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: c.primary, width: 2),
                  ),
                )
              : null,
          alignment: Alignment.center,
          child: DefaultTextStyle.merge(
            style: TextStyle(
              color: current ? c.headerText : c.headerMuted,
              fontWeight: FontWeight.w500,
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _navLink(BuildContext context, DpColors c, DpWebNavItem item) =>
      _navSurface(
        context,
        c,
        item: item,
        onTap: () => _pick(item.id),
        child: Text(item.label, overflow: TextOverflow.ellipsis),
      );

  Widget _navDropdown(BuildContext context, DpColors c, DpWebNavItem item) =>
      DpMenuButton(
        entries: [
          for (final child in item.children)
            (label: child.label, onSelect: () => _pick(child.id)),
        ],
        builder: (context, buttonFocus, toggle, isOpen) => _navSurface(
          context,
          c,
          item: item,
          focusNode: buttonFocus,
          onTap: toggle,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(item.label, overflow: TextOverflow.ellipsis),
              ),
              Icon(
                isOpen ? DpIcons.expandLess : DpIcons.expandMore,
                size: 18,
                color: item.isCurrent(widget.selectedId)
                    ? c.headerText
                    : c.headerMuted,
              ),
            ],
          ),
        ),
      );

  /// 시안의 입력 상자 모양이지만 실제 입력은 `DpCommandPalette` 가 받는다
  /// (`DpChromeBar` 와 같은 판단 — 입력 상태를 두 곳에서 관리하지 않는다).
  Widget _search(BuildContext context, DpColors c) {
    if (widget.onSearchTap == null) return const SizedBox.shrink();
    return SizedBox(
      width: 200,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const ValueKey('web-header-search'),
          onTap: widget.onSearchTap,
          borderRadius: BorderRadius.circular(DpRadius.input),
          child: Container(
            height: DpDensity.controlHeight,
            padding: const EdgeInsets.symmetric(horizontal: DpSpacing.sm),
            decoration: BoxDecoration(
              // 시안의 #1B1E29 는 토큰이 아니다 — 어두운 헤더 위의 표면 토큰을 쓴다.
              color: c.headerActive,
              border: Border.all(color: c.headerBorder),
              borderRadius: BorderRadius.circular(DpRadius.input),
            ),
            child: Row(
              children: [
                Icon(DpIcons.search, size: 16, color: c.headerMuted),
                const SizedBox(width: DpSpacing.xs),
                Flexible(
                  child: Text(
                    '검색',
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.labelMedium?.copyWith(color: c.headerMuted),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _account(BuildContext context, DpColors c) => DpMenuButton(
    entries: widget.accountEntries,
    builder: (context, buttonFocus, toggle, isOpen) => IconButton(
      key: const ValueKey('web-header-account'),
      focusNode: buttonFocus,
      // 색을 명시하지 않는다 — 어두운 헤더가 공급하는 IconTheme 을 상속한다.
      icon: const Icon(DpIcons.account),
      tooltip: '계정',
      style: IconButton.styleFrom(
        minimumSize: const Size.square(DpDensity.controlHeight),
        foregroundColor: c.headerText,
      ),
      onPressed: toggle,
    ),
  );

  Widget _burger(BuildContext context, DpColors c) => Semantics(
    // 함정 1·2: 헤더 표식과 합쳐지지 않도록 자기 노드로 가둔다.
    container: true,
    child: OutlinedButton.icon(
      key: const ValueKey('web-header-burger'),
      focusNode: _burgerFocus,
      icon: const Icon(DpIcons.menu, size: 18),
      label: const Text('메뉴'),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, DpDensity.controlHeight),
        padding: const EdgeInsets.symmetric(horizontal: DpSpacing.md),
        foregroundColor: c.headerText,
        side: BorderSide(color: c.headerBorder),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DpRadius.button),
        ),
      ),
      onPressed: () => setState(() => _expanded = !_expanded),
    ),
  );

  Widget _collapsedMenu(BuildContext context, DpColors c) {
    final rows = <Widget>[];
    for (final item in widget.items) {
      if (item.children.isEmpty) {
        rows.add(_menuRow(context, c, item.label, () => _pick(item.id)));
      } else {
        rows.add(_menuSection(context, c, item.label));
        for (final child in item.children) {
          rows.add(
            _menuRow(context, c, child.label, () => _pick(child.id), sub: true),
          );
        }
      }
    }
    rows.add(_menuSection(context, c, '계정'));
    for (final entry in widget.accountEntries) {
      rows.add(
        _menuRow(context, c, entry.label, () {
          setState(() => _expanded = false);
          entry.onSelect?.call();
        }, sub: true),
      );
    }

    return Container(
      key: const ValueKey('web-header-collapsed-menu'),
      decoration: BoxDecoration(
        color: c.headerBg,
        border: Border(bottom: BorderSide(color: c.headerBorder)),
      ),
      padding: const EdgeInsets.fromLTRB(
        DpSpacing.lg,
        DpSpacing.sm,
        DpSpacing.lg,
        DpSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: rows,
      ),
    );
  }

  Widget _menuRow(
    BuildContext context,
    DpColors c,
    String label,
    VoidCallback onTap, {
    bool sub = false,
  }) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      child: Container(
        // 최소 타깃 24(계약 2.0.0). 시안의 7px 세로 패딩으로는 시맨틱 박스가
        // 모자랄 수 있어 하한을 명시한다.
        constraints: const BoxConstraints(minHeight: DpDensity.controlHeight),
        padding: EdgeInsets.only(left: sub ? DpSpacing.md : 0),
        alignment: Alignment.centerLeft,
        child: Text(
          label,
          style: TextStyle(
            color: sub ? c.headerMuted : c.headerText,
            fontWeight: sub ? FontWeight.w400 : FontWeight.w500,
          ),
        ),
      ),
    ),
  );

  Widget _menuSection(BuildContext context, DpColors c, String label) =>
      Container(
        margin: const EdgeInsets.only(top: DpSpacing.sm),
        padding: const EdgeInsets.only(top: DpSpacing.sm),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: c.headerBorder)),
        ),
        child: Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: c.headerMuted),
        ),
      );
}
