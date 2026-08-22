import 'dart:async';

import 'package:app_links/app_links.dart';

import 'auth_callback.dart';
import '../../mission/state/mobile_mission_route.dart';

abstract interface class DeepLinkSource {
  Stream<Uri> get uriLinkStream;
}

final class AppLinksDeepLinkSource implements DeepLinkSource {
  AppLinksDeepLinkSource(this._appLinks);

  final AppLinks _appLinks;

  @override
  Stream<Uri> get uriLinkStream => _appLinks.uriLinkStream;
}

/// 앱 콜드/웜 스타트 양쪽에서 `devpath://` 딥링크를 받아 OAuth 콜백 code를 추출한다.
/// code가 파싱되면 [onCode]를 호출한다(AuthController.completeFromCode 연결).
class DeepLinkService {
  DeepLinkService(this._source, {required this.onCode, this.onRoute});

  final DeepLinkSource _source;
  final void Function(String code) onCode;
  final void Function(String location)? onRoute;
  StreamSubscription<Uri>? _sub;
  var _started = false;
  var _disposed = false;

  /// `app_links` 6.4.x stream is authoritative for both initial and warm links.
  /// Combining it with `getInitialLink` leaves a late native replay window, so
  /// this service subscribes once and lets the plugin own delivery ordering.
  Future<void> start() async {
    if (_started || _disposed) return;
    _started = true;
    _sub = _source.uriLinkStream.listen(_handle, onError: (_) {});
  }

  void _handle(Uri uri) {
    if (_disposed) return;
    final code = parseAuthCallbackCode(uri);
    if (code != null) {
      onCode(code);
      return;
    }
    final route = MobileMissionRoute.tryParseUri(uri);
    if (route != null) onRoute?.call(route.location);
  }

  Future<void> dispose() async {
    _disposed = true;
    await _sub?.cancel();
    _sub = null;
  }
}
