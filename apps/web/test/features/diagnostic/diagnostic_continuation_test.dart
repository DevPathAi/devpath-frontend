import 'dart:convert';

import 'package:devpath_web/src/features/diagnostic/state/diagnostic_continuation.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_test/flutter_test.dart';

const _guestId = '123e4567-e89b-42d3-a456-426614174000';
const _journeyId = 'AQIDBAUGBwgJCgsMDQ4PEA';
final _now = DateTime.utc(2026, 8, 15, 9);
const _preview = AssessmentResult(diagnosedLevel: 'MID', confidenceWeight: 0.8);

DiagnosticContinuation _continuation({
  DiagnosticContinuationPhase phase = DiagnosticContinuationPhase.preview,
  DateTime? expiresAt,
}) => DiagnosticContinuation(
  guestId: phase == DiagnosticContinuationPhase.track ? null : _guestId,
  track: 'BACKEND_SPRING',
  preview: switch (phase) {
    DiagnosticContinuationPhase.track ||
    DiagnosticContinuationPhase.questions => null,
    _ => _preview,
  },
  diagnosticStartedAt: phase == DiagnosticContinuationPhase.track ? null : _now,
  expiresAt: expiresAt ?? _now.add(diagnosticContinuationTtl),
  returnStage: phase,
  journeyId: _journeyId,
);

void main() {
  group('DiagnosticContinuation codec', () {
    test('v2 round-trip은 허용된 pointer/preview/시작 시각만 기록한다', () {
      final encoded = encodeDiagnosticContinuation(_continuation());
      final json = (jsonDecode(encoded) as Map).cast<String, dynamic>();

      expect(json.keys, {
        'version',
        'guestId',
        'track',
        'preview',
        'diagnosticStartedAt',
        'expiresAt',
        'returnStage',
        'journeyId',
      });
      expect(json, isNot(contains('answers')));
      expect(json, isNot(contains('oauth')));
      expect((json['preview'] as Map).keys, {
        'diagnosedLevel',
        'confidenceWeight',
      });

      final decoded = decodeDiagnosticContinuation(encoded, now: _now);
      expect(decoded.status, DiagnosticContinuationReadStatus.valid);
      expect(decoded.value, _continuation());
    });

    test('backend와 같은 30분 TTL에서 직전은 유효하고 정확한 경계는 만료다', () {
      final continuation = _continuation(
        expiresAt: _now.add(diagnosticContinuationTtl),
      );
      final raw = encodeDiagnosticContinuation(continuation);

      expect(
        decodeDiagnosticContinuation(
          raw,
          now: continuation.expiresAt.subtract(const Duration(microseconds: 1)),
        ).status,
        DiagnosticContinuationReadStatus.valid,
      );
      expect(
        decodeDiagnosticContinuation(raw, now: continuation.expiresAt).status,
        DiagnosticContinuationReadStatus.expired,
      );
      expect(
        decodeDiagnosticContinuation(
          raw,
          now: continuation.expiresAt.add(const Duration(microseconds: 1)),
        ).status,
        DiagnosticContinuationReadStatus.expired,
      );
    });

    test('현재 시각보다 30분 1마이크로초 이후인 envelope는 invalid다', () {
      final raw = encodeDiagnosticContinuation(
        _continuation(
          expiresAt: _now
              .add(diagnosticContinuationTtl)
              .add(const Duration(microseconds: 1)),
        ),
      );

      expect(
        decodeDiagnosticContinuation(raw, now: _now).status,
        DiagnosticContinuationReadStatus.invalid,
      );
    });

    test('손상·unknown version·unknown field는 fail-safe invalid다', () {
      expect(
        decodeDiagnosticContinuation('{', now: _now).status,
        DiagnosticContinuationReadStatus.invalid,
      );

      final base =
          jsonDecode(encodeDiagnosticContinuation(_continuation()))
              as Map<String, dynamic>;
      for (final mutation
          in <Map<String, dynamic> Function(Map<String, dynamic>)>[
            (json) => {...json, 'version': 3},
            (json) => {...json, 'version': 1.0},
            (json) => {...json, 'answers': <String>[]},
            (json) => {...json}..remove('journeyId'),
            (json) => {...json, 'journeyId': 'person@example.com'},
            (json) => {...json, 'guestId': 'not-a-uuid'},
            (json) => {...json, 'returnStage': 'future_phase'},
          ]) {
        expect(
          decodeDiagnosticContinuation(
            jsonEncode(mutation(base)),
            now: _now,
          ).status,
          DiagnosticContinuationReadStatus.invalid,
        );
      }
    });

    test('expiresAt은 calendar-valid RFC3339 UTC Z timestamp만 허용한다', () {
      final base =
          jsonDecode(encodeDiagnosticContinuation(_continuation()))
              as Map<String, dynamic>;
      for (final timestamp in <String>[
        '2026-08-15',
        '2026-08-15T09:30:00',
        '2026-08-15T18:30:00+09:00',
        '2026-02-30T09:30:00.000Z',
        '2026-08-15T25:00:00.000Z',
      ]) {
        expect(
          decodeDiagnosticContinuation(
            jsonEncode({...base, 'expiresAt': timestamp}),
            now: _now,
          ).status,
          DiagnosticContinuationReadStatus.invalid,
          reason: timestamp,
        );
      }
    });

    test('각 단계는 guest pointer와 last-valid preview 불변식을 지킨다', () {
      for (final phase in DiagnosticContinuationPhase.values) {
        final decoded = decodeDiagnosticContinuation(
          encodeDiagnosticContinuation(_continuation(phase: phase)),
          now: _now,
        );
        expect(decoded.status, DiagnosticContinuationReadStatus.valid);
        expect(decoded.value?.returnStage, phase);
      }

      final json =
          jsonDecode(encodeDiagnosticContinuation(_continuation()))
              as Map<String, dynamic>;
      json['preview'] = null;
      expect(
        decodeDiagnosticContinuation(jsonEncode(json), now: _now).status,
        DiagnosticContinuationReadStatus.invalid,
      );
    });
  });
}
