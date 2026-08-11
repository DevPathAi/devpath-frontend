import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import 'adsense_unit_view.dart' show AdSenseHandle;

/// index.html이 정의하는 심: createDevpathAdUnit(container, slotId, onResolved)
/// → { dispose } 반환. onResolved(status, height)는 정확히 1회 호출된다.
extension type _JsAdHandle._(JSObject _) implements JSObject {
  external void dispose();
}

@JS('createDevpathAdUnit')
external _JsAdHandle _createDevpathAdUnit(
  web.HTMLElement container,
  String slotId,
  JSFunction onResolved,
);

int _seq = 0;

/// viewType은 인스턴스마다 새로 만든다. 같은 `<ins>`를 재사용하면 구글이
/// "All ins elements ... already have ads in them"으로 거부한다.
AdSenseHandle createAdSenseHandle({
  required String slotId,
  required void Function(String status, double height) onResolved,
}) {
  final viewType = 'adsense-${_seq++}';
  _JsAdHandle? jsHandle;

  ui_web.platformViewRegistry.registerViewFactory(viewType, (int _) {
    final container = (web.document.createElement('div') as web.HTMLDivElement)
      ..style.width = '100%'
      // 확장 전에는 0높이 박스 밖으로 광고가 삐져나오지 않게 잘라둔다.
      ..style.overflow = 'hidden';
    final cb = ((JSString status, JSNumber height) => onResolved(
      status.toDart,
      height.toDartDouble,
    )).toJS;
    jsHandle = _createDevpathAdUnit(container, slotId, cb);
    return container;
  });

  return _WebHandle(viewType, () => jsHandle);
}

class _WebHandle implements AdSenseHandle {
  _WebHandle(this._viewType, this._jsHandle);
  final String _viewType;
  final _JsAdHandle? Function() _jsHandle;

  @override
  Widget get view => HtmlElementView(viewType: _viewType);

  @override
  void dispose() => _jsHandle()?.dispose();
}
