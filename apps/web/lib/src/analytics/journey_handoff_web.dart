import 'package:web/web.dart' as web;

import 'journey_handoff.dart';

class _WebJourneyIdStore implements JourneyIdStore {
  const _WebJourneyIdStore(this.key);

  final String key;

  @override
  String? read() => web.window.sessionStorage.getItem(key);

  @override
  void write(String journeyId) =>
      web.window.sessionStorage.setItem(key, journeyId);

  @override
  void clear() => web.window.sessionStorage.removeItem(key);
}

JourneyIdStore createJourneyIdStore() =>
    const _WebJourneyIdStore(journeyStorageKey);

JourneyIdStore createAnalyticsSessionIdStore() =>
    const _WebJourneyIdStore(analyticsSessionStorageKey);

void captureVisibleJourneyHandoff() {
  try {
    captureJourneyIdFromUri(
      Uri.parse(web.window.location.href),
      store: createJourneyIdStore(),
      replaceVisibleUri: (uri) =>
          web.window.history.replaceState(null, '', uri.toString()),
    );
  } catch (_) {
    // URL/storage capability must never prevent app startup.
  }
}
