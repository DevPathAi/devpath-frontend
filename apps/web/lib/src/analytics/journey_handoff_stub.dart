import 'journey_handoff.dart';

final _store = MemoryJourneyIdStore();
final _sessionStore = MemoryJourneyIdStore();

JourneyIdStore createJourneyIdStore() => _store;

JourneyIdStore createAnalyticsSessionIdStore() => _sessionStore;

void captureVisibleJourneyHandoff() {}
