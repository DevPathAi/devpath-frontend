import 'dart:js_interop';

import 'package:web/web.dart' as web;

String? readReleaseAnalyticsMarker() {
  try {
    return web.window.localStorage.getItem('leva.release.analytics.v1');
  } catch (_) {
    return null;
  }
}

Future<bool> sendReleaseAnalyticsKeepalive(String url, String payload) async {
  try {
    final headers = web.Headers()
      ..set('content-type', 'application/json; charset=utf-8');
    final response = await web.window
        .fetch(
          url.toJS,
          web.RequestInit(
            method: 'POST',
            headers: headers,
            body: payload.toJS,
            credentials: 'omit',
            keepalive: true,
          ),
        )
        .toDart;
    return response.ok;
  } catch (_) {
    return false;
  }
}
