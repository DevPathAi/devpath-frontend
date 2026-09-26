import 'package:flutter/material.dart';

/// 메뉴 항목. [onSelect] 가 null 이면 비활성.
typedef DpMenuEntry = ({String label, VoidCallback? onSelect});

/// 웹에서 **실제로 닫히는** 메뉴 버튼.
///
/// `MenuAnchor` 를 그냥 쓰면 Flutter 웹(시맨틱스 on)에서 Enter 로 연 뒤 Escape 가
/// 먹지 않고 DOM focus 가 body 로 빠진다. `childFocusNode` 만으로는 해결되지
/// 않는다(2026-09-17 CI 실측 FAIL). 열 때 첫 항목으로 focus 를 옮겨야
/// 한다(WAI-ARIA 메뉴 버튼 관례). 이 위젯은 그 조합을 한 곳에 가둔다 —
/// 새 메뉴를 만들 때 `MenuAnchor` 를 직접 쓰지 말고 이것을 쓴다.
class DpMenuButton extends StatefulWidget {
  const DpMenuButton({super.key, required this.entries, required this.builder});

  final List<DpMenuEntry> entries;

  /// [buttonFocus] 를 여는 위젯의 `focusNode` 로 넘겨야 닫을 때 focus 가 돌아온다.
  final Widget Function(
    BuildContext context,
    FocusNode buttonFocus,
    VoidCallback toggle,
    bool isOpen,
  )
  builder;

  @override
  State<DpMenuButton> createState() => _DpMenuButtonState();
}

class _DpMenuButtonState extends State<DpMenuButton> {
  final _buttonFocus = FocusNode(debugLabel: 'dp-menu-button');
  final _firstItemFocus = FocusNode(debugLabel: 'dp-menu-button-first-item');
  final _controller = MenuController();
  bool _open = false;

  @override
  void dispose() {
    _buttonFocus.dispose();
    _firstItemFocus.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_controller.isOpen) {
      _controller.close();
      return;
    }
    _controller.open();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _controller.isOpen) _firstItemFocus.requestFocus();
    });
  }

  void _select(DpMenuEntry entry) {
    // 먼저 닫는다 — 라우트가 바뀐 뒤에 닫으면 메뉴가 새 화면 위에 남는다.
    _controller.close();
    entry.onSelect?.call();
  }

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      controller: _controller,
      childFocusNode: _buttonFocus,
      onOpen: () => setState(() => _open = true),
      onClose: () => setState(() => _open = false),
      menuChildren: [
        for (final (index, entry) in widget.entries.indexed)
          MenuItemButton(
            focusNode: index == 0 ? _firstItemFocus : null,
            onPressed: entry.onSelect == null ? null : () => _select(entry),
            child: Text(entry.label),
          ),
      ],
      builder: (context, _, _) =>
          widget.builder(context, _buttonFocus, _toggle, _open),
    );
  }
}
