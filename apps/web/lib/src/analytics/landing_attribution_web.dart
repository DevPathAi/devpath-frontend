import 'package:web/web.dart' as web;

import 'landing_attribution.dart';

class _WebLandingAttributionStore implements LandingAttributionStore {
  const _WebLandingAttributionStore();

  @override
  LandingAttribution? read() => decodeLandingAttribution(
    web.window.sessionStorage.getItem(landingAttributionStorageKey),
  );

  @override
  void write(LandingAttribution attribution) =>
      web.window.sessionStorage.setItem(
        landingAttributionStorageKey,
        encodeLandingAttribution(attribution),
      );

  @override
  void clear() =>
      web.window.sessionStorage.removeItem(landingAttributionStorageKey);
}

LandingAttributionStore createLandingAttributionStore() =>
    const _WebLandingAttributionStore();

LandingAttribution? captureVisibleLandingAttribution() {
  final store = createLandingAttributionStore();
  try {
    return captureLandingAttributionFromUri(
      Uri.parse(web.window.location.href),
      store: store,
    );
  } catch (_) {
    // 잘못된 URL 또는 storage 거부가 앱 부팅을 막아서는 안 된다.
    return null;
  }
}
