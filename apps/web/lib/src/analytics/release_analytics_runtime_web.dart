import 'package:web/web.dart' as web;

String? readReleaseAnalyticsMarker() {
  try {
    return web.window.localStorage.getItem('leva.release.analytics.v1');
  } catch (_) {
    return null;
  }
}
