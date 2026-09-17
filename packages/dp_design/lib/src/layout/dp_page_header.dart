import 'package:flutter/material.dart';

import '../theme/dp_colors.dart';
import '../theme/dp_spacing.dart';
import 'dp_window_class.dart';

/// 제목 메뉴 한 항목 — 같은 계층의 형제 페이지.
typedef DpPageHeaderMenuItem = ({
  String label,
  bool selected,
  VoidCallback onSelect,
});

/// 본문 최상단 페이지 헤더(로드맵 Layer 2).
///
/// 모바일에서는 제목과 행동을 한 열로, 넓은 화면에서는 한 행으로 배치한다.
class DpPageHeader extends StatelessWidget {
  const DpPageHeader({
    super.key,
    required this.title,
    this.description,
    this.actions = const [],
    this.filters = const [],
    this.titleMenu = const [],
    this.titleMenuTooltip,
  });

  final String title;
  final String? description;
  final List<Widget> actions;

  /// 비어 있지 않으면 제목이 형제 페이지를 고르는 메뉴 버튼이 된다.
  ///
  /// 셸이 형제 목적지를 직접 보여 주지 못하는 폭(compact 하단 바)에서만 넘긴다 —
  /// 레일이 같은 목적지를 이미 보여 주는 폭에서는 같은 이동 수단이 둘이 된다.
  final List<DpPageHeaderMenuItem> titleMenu;

  /// 제목 메뉴 버튼의 도움말(예: '게시판 바꾸기').
  final String? titleMenuTooltip;

  /// 헤더 아래 필터 줄. 자식들은 Wrap의 형제로 배치되어 좁은 폭에서
  /// 줄바꿈한다 — Row를 통째로 받으면 줄바꿈이 일어나지 않는다.
  final List<Widget> filters;

  @override
  Widget build(BuildContext context) {
    final c = context.dpColors;
    final text = Theme.of(context).textTheme;
    final compact = context.windowClass == DpWindowClass.compact;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        compact ? DpSpacing.lg : DpSpacing.xl,
        compact ? DpSpacing.xl : DpSpacing.xxl,
        compact ? DpSpacing.lg : DpSpacing.xl,
        DpSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final titleBlock = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (titleMenu.isEmpty)
                    Semantics(
                      header: true,
                      child: Text(
                        title,
                        style: text.headlineSmall?.copyWith(
                          color: c.textPrimary,
                        ),
                      ),
                    )
                  else
                    _TitleMenu(
                      title: title,
                      items: titleMenu,
                      tooltip: titleMenuTooltip,
                    ),
                  if (description != null) ...[
                    const SizedBox(height: DpSpacing.sm),
                    Text(
                      description!,
                      key: const ValueKey('page-header-description'),
                      style: text.bodyMedium?.copyWith(color: c.textSecondary),
                    ),
                  ],
                ],
              );
              final actionBlock = Wrap(
                spacing: DpSpacing.sm,
                runSpacing: DpSpacing.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: actions,
              );

              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    titleBlock,
                    if (actions.isNotEmpty) ...[
                      const SizedBox(height: DpSpacing.lg),
                      actionBlock,
                    ],
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: titleBlock),
                  if (actions.isNotEmpty) ...[
                    const SizedBox(width: DpSpacing.xl),
                    ConstrainedBox(
                      constraints: constraints.hasBoundedWidth
                          ? BoxConstraints(maxWidth: constraints.maxWidth / 2)
                          : const BoxConstraints(),
                      child: actionBlock,
                    ),
                  ],
                ],
              );
            },
          ),
          if (filters.isNotEmpty) ...[
            const SizedBox(height: DpSpacing.md),
            KeyedSubtree(
              key: const ValueKey('page-header-filters'),
              child: Wrap(
                spacing: DpSpacing.sm,
                runSpacing: DpSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: filters,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 제목 자리의 메뉴 버튼. 제목 글꼴과 헤더 시맨틱을 그대로 유지한다.
class _TitleMenu extends StatefulWidget {
  const _TitleMenu({required this.title, required this.items, this.tooltip});

  final String title;
  final List<DpPageHeaderMenuItem> items;
  final String? tooltip;

  @override
  State<_TitleMenu> createState() => _TitleMenuState();
}

class _TitleMenuState extends State<_TitleMenu> {
  // 메뉴가 닫힐 때 focus 를 여는 버튼으로 되돌리려면 MenuAnchor 가 그 노드를 알아야 한다.
  final _buttonFocus = FocusNode(debugLabel: 'page-header-title-menu');

  @override
  void dispose() {
    _buttonFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dpColors;
    final text = Theme.of(context).textTheme;
    final title = widget.title;
    final items = widget.items;
    final tooltip = widget.tooltip;
    return MenuAnchor(
      childFocusNode: _buttonFocus,
      menuChildren: [
        for (final item in items)
          MenuItemButton(
            // 선택 표시가 없는 항목도 같은 폭을 비워 라벨이 한 줄로 정렬된다.
            leadingIcon: item.selected
                ? const Icon(Icons.check, size: 18)
                : const SizedBox(width: 18),
            onPressed: item.onSelect,
            child: Text(item.label),
          ),
      ],
      builder: (context, controller, _) {
        void toggle() =>
            controller.isOpen ? controller.close() : controller.open();
        // 헤더와 버튼을 한 시맨틱 노드로 합치면 웹에서 `<h2>` 가 버튼 역할을 삼키고
        // 도움말이 제목 텍스트에 섞인다(실측). 제목은 순수 헤더로, 메뉴는 옆의 버튼으로 둔다.
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: GestureDetector(
                // 제목 글자를 눌러도 열리지만 보조기술에는 옆의 버튼 하나만 알린다.
                excludeFromSemantics: true,
                behavior: HitTestBehavior.opaque,
                onTap: toggle,
                child: Semantics(
                  // 자기 노드로 가둔다 — 그러지 않으면 헤더 표식이 위로 합쳐져 옆의 버튼을
                  // 자식으로 거느리고, 웹 엔진은 자식이 있는 헤더를 `<h2>` 로 내지 않는다.
                  container: true,
                  header: true,
                  child: Text(
                    title,
                    style: text.headlineSmall?.copyWith(color: c.textPrimary),
                  ),
                ),
              ),
            ),
            IconButton(
              key: const ValueKey('page-header-title-menu'),
              focusNode: _buttonFocus,
              icon: const Icon(Icons.expand_more),
              color: c.textSecondary,
              tooltip: tooltip ?? '$title 메뉴',
              // 기본 40px 은 패딩으로만 48 을 채워 시맨틱 박스가 44px 에 못 미친다.
              style: IconButton.styleFrom(minimumSize: const Size.square(44)),
              onPressed: toggle,
            ),
          ],
        );
      },
    );
  }
}
