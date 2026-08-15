import 'package:web/web.dart' as web;

String readAnalyticsRuntimeUserAgent() {
  try {
    return web.window.navigator.userAgent;
  } catch (_) {
    // Browser capability failures must not prevent app startup.
    return '';
  }
}
