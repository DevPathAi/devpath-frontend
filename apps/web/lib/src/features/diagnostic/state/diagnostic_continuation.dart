import 'dart:convert';

import 'package:dp_core/dp_core.dart';

import '../../../analytics/journey_handoff.dart';

const diagnosticContinuationVersion = 1;
const diagnosticContinuationTtl = Duration(minutes: 30);

enum DiagnosticContinuationPhase {
  track,
  questions,
  preview,
  auth,
  consent,
  claim,
  saved,
}

class DiagnosticContinuation {
  const DiagnosticContinuation({
    this.version = diagnosticContinuationVersion,
    required this.guestId,
    required this.track,
    required this.preview,
    required this.expiresAt,
    required this.returnStage,
    required this.journeyId,
  });

  final int version;
  final String? guestId;
  final String track;
  final AssessmentResult? preview;
  final DateTime expiresAt;
  final DiagnosticContinuationPhase returnStage;
  final String journeyId;

  DiagnosticContinuation copyWith({
    String? guestId,
    AssessmentResult? preview,
    DateTime? expiresAt,
    DiagnosticContinuationPhase? returnStage,
  }) => DiagnosticContinuation(
    guestId: guestId ?? this.guestId,
    track: track,
    preview: preview ?? this.preview,
    expiresAt: expiresAt ?? this.expiresAt,
    returnStage: returnStage ?? this.returnStage,
    journeyId: journeyId,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiagnosticContinuation &&
          version == other.version &&
          guestId == other.guestId &&
          track == other.track &&
          preview == other.preview &&
          expiresAt == other.expiresAt &&
          returnStage == other.returnStage &&
          journeyId == other.journeyId;

  @override
  int get hashCode => Object.hash(
    version,
    guestId,
    track,
    preview,
    expiresAt,
    returnStage,
    journeyId,
  );
}

enum DiagnosticContinuationReadStatus { valid, invalid, expired }

class DiagnosticContinuationRead {
  const DiagnosticContinuationRead._(this.status, this.value);

  const DiagnosticContinuationRead.valid(DiagnosticContinuation value)
    : this._(DiagnosticContinuationReadStatus.valid, value);

  const DiagnosticContinuationRead.invalid()
    : this._(DiagnosticContinuationReadStatus.invalid, null);

  const DiagnosticContinuationRead.expired()
    : this._(DiagnosticContinuationReadStatus.expired, null);

  final DiagnosticContinuationReadStatus status;
  final DiagnosticContinuation? value;
}

const _tracks = <String>{
  'BACKEND_SPRING',
  'FRONTEND_REACT',
  'MOBILE_FLUTTER',
  'DEVOPS',
  'FULLSTACK',
  'PYTHON_BACKEND',
};
const _levels = <String>{'JUNIOR', 'MID', 'SENIOR'};
final _guestIdPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
);
final _utcTimestampPattern = RegExp(
  r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.(\d{1,6}))?Z$',
);
const _envelopeKeys = <String>{
  'version',
  'guestId',
  'track',
  'preview',
  'expiresAt',
  'returnStage',
  'journeyId',
};
const _previewKeys = <String>{'diagnosedLevel', 'confidenceWeight'};

String encodeDiagnosticContinuation(DiagnosticContinuation value) {
  if (!_isValid(value)) {
    throw ArgumentError.value(
      value,
      'value',
      'invalid diagnostic continuation',
    );
  }
  return jsonEncode({
    'version': value.version,
    'guestId': value.guestId,
    'track': value.track,
    'preview': value.preview == null
        ? null
        : {
            'diagnosedLevel': value.preview!.diagnosedLevel,
            'confidenceWeight': value.preview!.confidenceWeight,
          },
    'expiresAt': value.expiresAt.toUtc().toIso8601String(),
    'returnStage': value.returnStage.name,
    'journeyId': value.journeyId,
  });
}

DiagnosticContinuationRead decodeDiagnosticContinuation(
  String raw, {
  required DateTime now,
}) {
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return const DiagnosticContinuationRead.invalid();
    final json = decoded.cast<String, dynamic>();
    if (!_hasExactKeys(json, _envelopeKeys) ||
        json['version'] is! int ||
        json['version'] != diagnosticContinuationVersion ||
        json['guestId'] is! String? ||
        json['track'] is! String ||
        json['expiresAt'] is! String ||
        json['returnStage'] is! String ||
        json['journeyId'] is! String) {
      return const DiagnosticContinuationRead.invalid();
    }

    final phase = DiagnosticContinuationPhase.values
        .where((value) => value.name == json['returnStage'])
        .firstOrNull;
    final expiresAt = _parseStrictUtcTimestamp(json['expiresAt'] as String);
    if (phase == null || expiresAt == null) {
      return const DiagnosticContinuationRead.invalid();
    }

    AssessmentResult? preview;
    final previewJson = json['preview'];
    if (previewJson != null) {
      if (previewJson is! Map) {
        return const DiagnosticContinuationRead.invalid();
      }
      final map = previewJson.cast<String, dynamic>();
      if (!_hasExactKeys(map, _previewKeys) ||
          map['diagnosedLevel'] is! String ||
          (map['confidenceWeight'] != null &&
              map['confidenceWeight'] is! num)) {
        return const DiagnosticContinuationRead.invalid();
      }
      preview = AssessmentResult(
        diagnosedLevel: map['diagnosedLevel'] as String,
        confidenceWeight: (map['confidenceWeight'] as num?)?.toDouble(),
      );
    }

    final continuation = DiagnosticContinuation(
      guestId: json['guestId'] as String?,
      track: json['track'] as String,
      preview: preview,
      expiresAt: expiresAt,
      returnStage: phase,
      journeyId: json['journeyId'] as String,
    );
    if (!_isValid(continuation)) {
      return const DiagnosticContinuationRead.invalid();
    }
    final utcNow = now.toUtc();
    if (expiresAt.difference(utcNow) > diagnosticContinuationTtl) {
      return const DiagnosticContinuationRead.invalid();
    }
    // Redis guest session expires at the boundary, so equality is expired too.
    if (!utcNow.isBefore(expiresAt)) {
      return const DiagnosticContinuationRead.expired();
    }
    return DiagnosticContinuationRead.valid(continuation);
  } catch (_) {
    return const DiagnosticContinuationRead.invalid();
  }
}

bool _hasExactKeys(Map<String, dynamic> json, Set<String> expected) =>
    json.length == expected.length && json.keys.every(expected.contains);

DateTime? _parseStrictUtcTimestamp(String raw) {
  final match = _utcTimestampPattern.firstMatch(raw);
  if (match == null) return null;
  final year = int.parse(match[1]!);
  final month = int.parse(match[2]!);
  final day = int.parse(match[3]!);
  final hour = int.parse(match[4]!);
  final minute = int.parse(match[5]!);
  final second = int.parse(match[6]!);
  final fraction = match[7];
  final micros = fraction == null ? 0 : int.parse(fraction.padRight(6, '0'));
  final parsed = DateTime.utc(
    year,
    month,
    day,
    hour,
    minute,
    second,
    micros ~/ 1000,
    micros % 1000,
  );
  if (parsed.year != year ||
      parsed.month != month ||
      parsed.day != day ||
      parsed.hour != hour ||
      parsed.minute != minute ||
      parsed.second != second ||
      parsed.millisecond != micros ~/ 1000 ||
      parsed.microsecond != micros % 1000) {
    return null;
  }
  return parsed;
}

bool _isValid(DiagnosticContinuation value) {
  if (value.version != diagnosticContinuationVersion ||
      !_tracks.contains(value.track) ||
      !isValidJourneyId(value.journeyId) ||
      !value.expiresAt.isUtc) {
    return false;
  }
  final confidence = value.preview?.confidenceWeight;
  if (value.preview != null &&
      (!_levels.contains(value.preview!.diagnosedLevel) ||
          (confidence != null &&
              (!confidence.isFinite || confidence < 0 || confidence > 1)))) {
    return false;
  }
  return switch (value.returnStage) {
    DiagnosticContinuationPhase.track =>
      value.guestId == null && value.preview == null,
    DiagnosticContinuationPhase.questions =>
      _isGuestId(value.guestId) && value.preview == null,
    DiagnosticContinuationPhase.preview ||
    DiagnosticContinuationPhase.auth ||
    DiagnosticContinuationPhase.consent ||
    DiagnosticContinuationPhase.claim ||
    DiagnosticContinuationPhase.saved =>
      _isGuestId(value.guestId) && value.preview != null,
  };
}

bool _isGuestId(String? value) =>
    value != null && _guestIdPattern.hasMatch(value);
