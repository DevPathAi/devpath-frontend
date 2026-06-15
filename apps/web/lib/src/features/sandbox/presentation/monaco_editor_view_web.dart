import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import 'monaco_editor_view.dart' show MonacoHandle;

/// index.html 셈이 반환하는 JS 핸들: { dispose(), layout() }.
extension type _JsEditorHandle._(JSObject _) implements JSObject {
  external void dispose();
  external void layout();
}

/// index.html이 정의하는 셈: createDevpathEditor(container, code, onChange, onEscape)
/// → { dispose, layout } 반환.
@JS('createDevpathEditor')
external _JsEditorHandle _createDevpathEditor(
  web.HTMLElement container,
  String initialCode,
  JSFunction onChange,
  JSFunction onEscape,
);

int _seq = 0;

/// F5-a 반영: viewType은 핸들 생성 시(=State.initState 경유) **1회** 만들고 보관.
/// 함수형 build에서 매 rebuild마다 만들면 viewFactory 무한 증식.
MonacoHandle createMonacoHandle({
  required String initialCode,
  ValueChanged<String>? onChanged,
  VoidCallback? onEscape,
}) {
  final viewType = 'monaco-${_seq++}';
  _JsEditorHandle? jsHandle;

  ui_web.platformViewRegistry.registerViewFactory(viewType, (int _) {
    final container = (web.document.createElement('div') as web.HTMLDivElement)
      ..style.width = '100%'
      ..style.height = '100%';
    final cb = ((JSString v) => onChanged?.call(v.toDart)).toJS;
    final esc = (() => onEscape?.call()).toJS; // F5-c: Esc→dart sentinel
    jsHandle = _createDevpathEditor(container, initialCode, cb, esc);
    return container;
  });

  return _WebHandle(viewType, () => jsHandle);
}

class _WebHandle implements MonacoHandle {
  _WebHandle(this._viewType, this._jsHandle);
  final String _viewType;
  final _JsEditorHandle? Function() _jsHandle;

  @override
  Widget get view => HtmlElementView(viewType: _viewType);

  @override
  void layout() => _jsHandle()?.layout(); // F5-b

  @override
  void dispose() => _jsHandle()?.dispose(); // F5-a: JS editor.dispose()
}
