import 'dart:convert';

import 'landing_attribution_web.dart'
    if (dart.library.io) 'landing_attribution_stub.dart';

const landingAttributionStorageKey = 'leva.attribution.utm.v1';
const _sourceKey = 'utm_source';
const _mediumKey = 'utm_medium';
const _contentKey = 'utm_content';

class LandingAttribution {
  const LandingAttribution({
    required this.source,
    required this.medium,
    required this.content,
  });

  final String source;
  final String medium;
  final String content;

  Map<String, String> toJson() => {
    _sourceKey: source,
    _mediumKey: medium,
    _contentKey: content,
  };

  @override
  bool operator ==(Object other) =>
      other is LandingAttribution &&
      source == other.source &&
      medium == other.medium &&
      content == other.content;

  @override
  int get hashCode => Object.hash(source, medium, content);
}

abstract interface class LandingAttributionStore {
  LandingAttribution? read();
  void write(LandingAttribution attribution);
  void clear();
}

class MemoryLandingAttributionStore implements LandingAttributionStore {
  LandingAttribution? _value;

  @override
  LandingAttribution? read() => _value;

  @override
  void write(LandingAttribution attribution) => _value = attribution;

  @override
  void clear() => _value = null;
}

LandingAttribution? decodeLandingAttribution(String? raw) {
  if (raw == null) return null;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic> ||
        decoded.length != 3 ||
        decoded.keys.toSet().difference({
          _sourceKey,
          _mediumKey,
          _contentKey,
        }).isNotEmpty) {
      return null;
    }
    return _validatedAttribution(
      source: decoded[_sourceKey],
      medium: decoded[_mediumKey],
      content: decoded[_contentKey],
    );
  } catch (_) {
    return null;
  }
}

String encodeLandingAttribution(LandingAttribution attribution) =>
    jsonEncode(attribution.toJson());

LandingAttribution? _validatedAttribution({
  required Object? source,
  required Object? medium,
  required Object? content,
}) {
  if (source != 'leva.ai.kr' || medium != 'cta' || content is! String) {
    return null;
  }
  if (!RegExp(r'^[a-z0-9_]{1,64}$').hasMatch(content)) return null;
  return LandingAttribution(
    source: source as String,
    medium: medium as String,
    content: content,
  );
}

LandingAttribution? attributionFromUri(Uri uri) {
  final source = uri.queryParametersAll[_sourceKey];
  final medium = uri.queryParametersAll[_mediumKey];
  final content = uri.queryParametersAll[_contentKey];
  if (source?.length != 1 || medium?.length != 1 || content?.length != 1) {
    return null;
  }
  return _validatedAttribution(
    source: source!.single,
    medium: medium!.single,
    content: content!.single,
  );
}

LandingAttribution? captureLandingAttributionFromUri(
  Uri current, {
  required LandingAttributionStore store,
}) {
  final incoming = attributionFromUri(current);
  if (incoming != null) {
    store.write(incoming);
    return incoming;
  }
  return store.read();
}

LandingAttributionStore landingAttributionStore() =>
    createLandingAttributionStore();

LandingAttribution? captureLandingAttributionFromVisibleUrl() =>
    captureVisibleLandingAttribution();
