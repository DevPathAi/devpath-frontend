import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:dp_core/dp_core.dart';

import 'auth_callback.dart';

/// 앱 콜드/웜 스타트 양쪽에서 `devpath://` 딥링크를 받아 OAuth 콜백 토큰을 추출한다.
/// 토큰이 파싱되면 [onTokens]를 호출한다(AuthController.completeFromDeepLink 연결).
class DeepLinkService {
  DeepLinkService(this._appLinks, {required this.onTokens});

  final AppLinks _appLinks;
  final void Function(TokenPair tokens) onTokens;
  StreamSubscription<Uri>? _sub;

  /// 콜드 스타트 초기 링크 처리 + 웜 스타트 스트림 구독.
  Future<void> start() async {
    final initial = await _appLinks.getInitialLink();
    if (initial != null) _handle(initial);
    _sub = _appLinks.uriLinkStream.listen(_handle);
  }

  void _handle(Uri uri) {
    final tokens = parseAuthCallback(uri);
    if (tokens != null) onTokens(tokens);
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
  }
}
