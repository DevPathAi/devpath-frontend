import 'dart:convert';
import 'dart:math';

import 'journey_handoff_web.dart'
    if (dart.library.io) 'journey_handoff_stub.dart';

const journeyQueryParameter = 'journeyId';
const journeyStorageKey = 'leva.analytics.journey.v1';
const analyticsSessionStorageKey = 'leva.analytics.session.v1';

abstract interface class JourneyIdStore {
  String? read();
  void write(String journeyId);
  void clear();
}

class MemoryJourneyIdStore implements JourneyIdStore {
  String? _value;

  @override
  String? read() => _value;

  @override
  void write(String journeyId) => _value = journeyId;

  @override
  void clear() => _value = null;
}

typedef RandomBytes = List<int> Function(int length);

List<int> _secureRandomBytes(int length) {
  final random = Random.secure();
  return List.generate(length, (_) => random.nextInt(256));
}

String generateOpaqueJourneyId({RandomBytes randomBytes = _secureRandomBytes}) {
  final bytes = randomBytes(16);
  if (bytes.length != 16 || bytes.any((value) => value < 0 || value > 255)) {
    throw ArgumentError.value(bytes, 'randomBytes', 'must return 16 bytes');
  }
  return base64UrlEncode(bytes).replaceAll('=', '');
}

bool isValidJourneyId(String? value) =>
    value != null && RegExp(r'^[A-Za-z0-9_-]{22}$').hasMatch(value);

String getOrCreateJourneyId(
  JourneyIdStore store, {
  RandomBytes randomBytes = _secureRandomBytes,
}) {
  final stored = store.read();
  if (isValidJourneyId(stored)) return stored!;
  if (stored != null) store.clear();
  final created = generateOpaqueJourneyId(randomBytes: randomBytes);
  store.write(created);
  return created;
}

Uri _replaceJourneyValues(Uri uri, List<String>? values) {
  final query = <String, dynamic>{
    for (final entry in uri.queryParametersAll.entries)
      if (entry.key != journeyQueryParameter) entry.key: entry.value,
  };
  if (values != null) query[journeyQueryParameter] = values;
  if (query.isEmpty) {
    final text = uri.toString();
    final queryStart = text.indexOf('?');
    if (queryStart == -1) return uri;
    final fragmentStart = text.indexOf('#', queryStart);
    return Uri.parse(
      text.replaceRange(
        queryStart,
        fragmentStart == -1 ? text.length : fragmentStart,
        '',
      ),
    );
  }
  return uri.replace(queryParameters: query);
}

Uri buildJourneyHandoffUri(Uri target, String journeyId) {
  if (!isValidJourneyId(journeyId)) {
    throw ArgumentError.value(journeyId, 'journeyId', 'must be opaque');
  }
  return _replaceJourneyValues(target, [journeyId]);
}

String? captureJourneyIdFromUri(
  Uri current, {
  required JourneyIdStore store,
  required void Function(Uri cleanUri) replaceVisibleUri,
}) {
  final incomingValues = current.queryParametersAll[journeyQueryParameter];
  if (incomingValues == null) {
    final stored = store.read();
    return isValidJourneyId(stored) ? stored : null;
  }

  // Visible cleanup always happens before trusting or storing the value.
  replaceVisibleUri(_replaceJourneyValues(current, null));
  if (incomingValues.length != 1 || !isValidJourneyId(incomingValues.single)) {
    return null;
  }
  final incoming = incomingValues.single;
  final stored = store.read();
  if (stored != null && isValidJourneyId(stored) && stored != incoming) {
    return null;
  }
  if (stored != null && !isValidJourneyId(stored)) store.clear();
  store.write(incoming);
  return incoming;
}

JourneyIdStore journeyIdStore() => createJourneyIdStore();

JourneyIdStore analyticsSessionIdStore() => createAnalyticsSessionIdStore();

void captureJourneyHandoffFromVisibleUrl() => captureVisibleJourneyHandoff();
