import 'package:flutter/widgets.dart';

import 'monaco_editor_view_stub.dart'
    if (dart.library.js_interop) 'monaco_editor_view_web.dart'
    as impl;

/// web 구현이 반환하는 핸들 — viewType 위젯 + 생명주기(dispose)/layout 제어.
/// stub도 동일 인터페이스를 만족(아래 stub 참조).
abstract class MonacoHandle {
  Widget get view;
  void layout(); // F5-b: 가시화 시 재레이아웃
  void dispose(); // F5-a: JS editor.dispose()
}

/// 코드 에디터. web=Monaco 임베드, 그 외(테스트 포함)=stub.
///
/// F5-a 반영: viewType은 **State에서 1회**(initState) 생성·보관한다. 함수형 build에서
/// 매 rebuild마다 `_seq++`로 viewType을 만들면 viewFactory가 무한 증식·메모리 누수가 난다.
class MonacoEditorView extends StatefulWidget {
  const MonacoEditorView({
    super.key,
    required this.initialCode,
    this.onChanged,
  });
  final String initialCode;
  final ValueChanged<String>? onChanged;

  @override
  State<MonacoEditorView> createState() => MonacoEditorViewState();
}

class MonacoEditorViewState extends State<MonacoEditorView> {
  late final MonacoHandle _handle; // F5-a: viewType/에디터 1회 생성·보관
  final FocusNode _focusNode = FocusNode(
    debugLabel: 'monaco-sentinel',
  ); // F5-c DD7

  @override
  void initState() {
    super.initState();
    _handle = impl.createMonacoHandle(
      initialCode: widget.initialCode,
      onChanged: widget.onChanged,
      onEscape: () => _focusNode.requestFocus(), // Esc→컨테이너 밖 sentinel로 탈출
    );
  }

  /// F5-b: SandboxLayout이 에디터 가시화 시 호출(IndexedStack 토글 보정).
  void layout() => _handle.layout();

  @override
  void dispose() {
    _handle.dispose(); // F5-a: JS editor.dispose()
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // F5-c: 외곽 Focus(sentinel) — Esc 시 web 구현이 이리로 포커스를 넘긴다.
    return Focus(focusNode: _focusNode, child: _handle.view);
  }
}
