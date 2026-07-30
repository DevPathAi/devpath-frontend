import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'dp_command.dart';

/// 하위 위젯이 명령 팔레트를 프로그래밍적으로 열기 위한 공개 인텐트.
class OpenCommandPaletteIntent extends Intent {
  const OpenCommandPaletteIntent();
}

/// Ctrl/Cmd+K 명령 팔레트(로드맵 §Phase1). 앱 트리 상단을 감싸며,
/// 결과 소스([commands])는 앱이 주입한다. 라우팅 비의존.
class DpCommandPalette extends StatefulWidget {
  const DpCommandPalette({
    super.key,
    required this.child,
    required this.commands,
    this.hintText = '명령·이동 검색',
  });

  final Widget child;
  final List<DpCommand> commands;
  final String hintText;

  @override
  State<DpCommandPalette> createState() => _DpCommandPaletteState();
}

class _DpCommandPaletteState extends State<DpCommandPalette> {
  final SearchController _controller = SearchController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _open() {
    if (!_controller.isOpen) _controller.openView();
  }

  Iterable<Widget> _suggestions(
    BuildContext context,
    SearchController controller,
  ) {
    final q = controller.text.trim().toLowerCase();
    final matches = q.isEmpty
        ? widget.commands
        : widget.commands.where((c) => c.label.toLowerCase().contains(q));
    return [
      for (final c in matches)
        ListTile(
          leading: Icon(c.icon),
          title: Text(c.label),
          onTap: () {
            controller.closeView(null);
            c.onInvoke();
          },
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.keyK, control: true):
            OpenCommandPaletteIntent(),
        SingleActivator(LogicalKeyboardKey.keyK, meta: true):
            OpenCommandPaletteIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          OpenCommandPaletteIntent: CallbackAction<OpenCommandPaletteIntent>(
            onInvoke: (_) {
              _open();
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: Stack(
            children: [
              widget.child,
              // 0-크기 앵커: openView()가 전체화면 검색 뷰를 오버레이로 연다.
              Positioned(
                left: 0,
                top: 0,
                child: SearchAnchor(
                  searchController: _controller,
                  viewHintText: widget.hintText,
                  isFullScreen: false,
                  builder: (context, controller) => const SizedBox.shrink(),
                  suggestionsBuilder: _suggestions,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
