import 'dart:async';

import 'package:app_links/app_links.dart';

import 'auth_callback.dart';

/// 앱 콜드/웜 스타트 양쪽에서 `devpath://` 딥링크를 받아 OAuth 콜백 code를 추출한다.
/// code가 파싱되면 [onCode]를 호출한다(AuthController.completeFromCode 연결).
class DeepLinkService {
  DeepLinkService(this._appLinks, {required this.onCode});

  final AppLinks _appLinks;
  final void Function(String code) onCode;
  StreamSubscription<Uri>? _sub;

  /// 콜드 스타트 초기 링크 처리 + 웜 스타트 스트림 구독.
  Future<void> start() async {
    final initial = await _appLinks.getInitialLink();
    if (initial != null) _handle(initial);
    _sub = _appLinks.uriLinkStream.listen(_handle);
  }

  void _handle(Uri uri) {
    final code = parseAuthCallbackCode(uri);
    if (code != null) onCode(code);
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
  }
}
