import 'landing_attribution.dart';

final _store = MemoryLandingAttributionStore();

LandingAttributionStore createLandingAttributionStore() => _store;

LandingAttribution? captureVisibleLandingAttribution() => _store.read();
