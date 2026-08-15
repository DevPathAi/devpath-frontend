import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:devpath_web/src/analytics/analytics_contract.dart';
import 'package:flutter_test/flutter_test.dart';

const common = <String, Object?>{
  'contract_version': 'mission-spine.analytics.v1',
  'occurred_at': '2026-08-15T10:00:00.000Z',
  'environment': 'production',
  'app_version': 'abc123',
  'session_id': 'AQIDBAUGBwgJCgsMDQ4PEA',
  'journey_id': 'EREREREREREREREREREREQ',
};

const canonicalContractSha256 =
    '486256fd212b96ea2fec0c6a95e22676b708989f94c0ca974276d6bd5f6b4908';

const expectedSpecs = <String, Map<String, Object>>{
  'landing_viewed': {
    'allowed': ['page_view_id'],
    'required': ['page_view_id'],
    'requiredAny': <List<String>>[],
    'dedupe': [
      ['session_id', 'page_view_id'],
    ],
  },
  'landing_diagnostic_cta_clicked': {
    'allowed': ['page_view_id', 'cta_location'],
    'required': ['page_view_id', 'cta_location'],
    'requiredAny': <List<String>>[],
    'dedupe': [
      ['page_view_id', 'cta_location'],
    ],
  },
  'diagnostic_started': {
    'allowed': ['track', 'guest_id', 'assessment_id'],
    'required': ['track'],
    'requiredAny': [
      ['guest_id', 'assessment_id'],
    ],
    'dedupe': [
      ['guest_id'],
      ['assessment_id'],
    ],
  },
  'diagnostic_completed': {
    'allowed': ['guest_id', 'assessment_id', 'diagnosed_level', 'duration_ms'],
    'required': ['diagnosed_level', 'duration_ms'],
    'requiredAny': [
      ['guest_id', 'assessment_id'],
    ],
    'dedupe': [
      ['guest_id'],
      ['assessment_id'],
    ],
  },
  'result_claimed': {
    'allowed': ['guest_id', 'assessment_id', 'user_id', 'claim_outcome'],
    'required': ['guest_id', 'user_id', 'claim_outcome'],
    'requiredAny': <List<String>>[],
    'dedupe': [
      ['assessment_id'],
      ['guest_id', 'user_id'],
    ],
  },
  'path_generated': {
    'allowed': ['path_id', 'assessment_id', 'user_id'],
    'required': ['path_id', 'assessment_id', 'user_id'],
    'requiredAny': <List<String>>[],
    'dedupe': [
      ['path_id'],
    ],
  },
  'existing_path_continued': {
    'allowed': ['user_id', 'path_id', 'assessment_id', 'guest_id'],
    'required': ['user_id', 'path_id'],
    'requiredAny': [
      ['assessment_id', 'guest_id'],
    ],
    'dedupe': [
      ['user_id', 'path_id', 'assessment_id'],
      ['user_id', 'path_id', 'guest_id'],
    ],
  },
  'path_first_viewed': {
    'allowed': ['user_id', 'path_id', 'originating_session_id'],
    'required': ['user_id', 'path_id', 'originating_session_id'],
    'requiredAny': <List<String>>[],
    'dedupe': [
      ['user_id', 'path_id'],
    ],
  },
  'first_mission_started': {
    'allowed': ['user_id', 'path_id', 'week_num', 'task_id', 'first_open'],
    'required': ['user_id', 'path_id', 'week_num', 'task_id', 'first_open'],
    'requiredAny': <List<String>>[],
    'dedupe': [
      ['user_id', 'task_id', 'first_open'],
    ],
  },
  'first_practice_succeeded': {
    'allowed': [
      'user_id',
      'path_id',
      'task_id',
      'content_id',
      'run_id',
      'first_successful_run',
    ],
    'required': [
      'user_id',
      'path_id',
      'task_id',
      'content_id',
      'run_id',
      'first_successful_run',
    ],
    'requiredAny': <List<String>>[],
    'dedupe': [
      ['user_id', 'task_id', 'first_successful_run'],
    ],
  },
  'contextual_review_viewed': {
    'allowed': [
      'user_id',
      'task_id',
      'review_id',
      'approved_context_field_count',
      'next_action_outcome',
      'first_view',
    ],
    'required': [
      'user_id',
      'task_id',
      'review_id',
      'approved_context_field_count',
      'next_action_outcome',
      'first_view',
    ],
    'requiredAny': <List<String>>[],
    'dedupe': [
      ['user_id', 'task_id', 'review_id', 'first_view'],
    ],
  },
};

const validEventProperties = <String, Map<String, Object?>>{
  'landing_viewed': {'page_view_id': 'ISEhISEhISEhISEhISEhIQ'},
  'landing_diagnostic_cta_clicked': {
    'page_view_id': 'ISEhISEhISEhISEhISEhIQ',
    'cta_location': 'hero',
  },
  'diagnostic_started': {
    'track': 'BACKEND_SPRING',
    'guest_id': '123e4567-e89b-42d3-a456-426614174000',
  },
  'diagnostic_completed': {
    'assessment_id': 11,
    'diagnosed_level': 'MID',
    'duration_ms': 12000,
  },
  'result_claimed': {
    'guest_id': '123e4567-e89b-42d3-a456-426614174000',
    'assessment_id': 11,
    'user_id': '101',
    'claim_outcome': 'new_path_eligible',
  },
  'path_generated': {'path_id': 21, 'assessment_id': 11, 'user_id': '101'},
  'existing_path_continued': {
    'user_id': '101',
    'path_id': 21,
    'assessment_id': 11,
  },
  'path_first_viewed': {
    'user_id': '101',
    'path_id': 21,
    'originating_session_id': 'AQIDBAUGBwgJCgsMDQ4PEA',
  },
  'first_mission_started': {
    'user_id': '101',
    'path_id': 21,
    'week_num': 1,
    'task_id': 31,
    'first_open': true,
  },
  'first_practice_succeeded': {
    'user_id': '101',
    'path_id': 21,
    'task_id': 31,
    'content_id': 41,
    'run_id': 51,
    'first_successful_run': true,
  },
  'contextual_review_viewed': {
    'user_id': '101',
    'task_id': 31,
    'review_id': 61,
    'approved_context_field_count': 1,
    'next_action_outcome': 'next_mission',
    'first_view': true,
  },
};

void main() {
  group('Mission Spine analytics contract', () {
    test('matches the canonical versioned JSON contract', () {
      final canonicalFile = File(
        'lib/src/analytics/mission-spine.analytics.v1.json',
      );
      // Git stores this contract as LF. Some existing Windows worktrees were
      // created before the eol=lf attribute and still expose CRLF bytes, so
      // hash the canonical repository representation rather than checkout EOL.
      final canonicalText = canonicalFile.readAsStringSync().replaceAll(
        '\r\n',
        '\n',
      );
      final canonical = jsonDecode(canonicalText) as Map<String, dynamic>;
      final actualEvents = <String, Object?>{
        for (final entry in analyticsEventSpecs.entries)
          entry.key: {
            'consent_requirement': entry.value.consentRequirement,
            'timestamp_source': entry.value.timestampSource,
            'allowed': entry.value.allowed,
            'required': entry.value.required,
            'requiredAny': entry.value.requiredAny,
            'dedupe': entry.value.dedupe,
          },
      };

      expect(
        sha256.convert(utf8.encode(canonicalText)).toString(),
        canonicalContractSha256,
      );
      expect(canonical['version'], analyticsContractVersion);
      expect(canonical['privacyPolicyVersion'], analyticsPrivacyPolicyVersion);
      expect(canonical['valuePolicyVersion'], analyticsValuePolicyVersion);
      expect(canonical['commonProperties'], analyticsCommonProperties.toList());
      expect(canonical['bannedProperties'], analyticsBannedProperties.toList());
      expect(canonical['events'], actualEvents);
    });

    test('uses the approved version and exact event allowlist', () {
      expect(analyticsContractVersion, 'mission-spine.analytics.v1');
      expect(analyticsEventSpecs.keys, [
        'landing_viewed',
        'landing_diagnostic_cta_clicked',
        'diagnostic_started',
        'diagnostic_completed',
        'result_claimed',
        'path_generated',
        'existing_path_continued',
        'path_first_viewed',
        'first_mission_started',
        'first_practice_succeeded',
        'contextual_review_viewed',
      ]);
      for (final entry in expectedSpecs.entries) {
        final actual = analyticsEventSpecs[entry.key]!;
        expect(actual.allowed, entry.value['allowed'], reason: entry.key);
        expect(actual.required, entry.value['required'], reason: entry.key);
        expect(
          actual.requiredAny,
          entry.value['requiredAny'],
          reason: entry.key,
        );
        expect(actual.dedupe, entry.value['dedupe'], reason: entry.key);
      }
    });

    test('declares consent and timestamp semantics for every event', () {
      for (final spec in analyticsEventSpecs.values) {
        expect(spec.consentRequirement, 'analytics_permission');
        expect(spec.timestampSource, 'client_event_time');
      }
    });

    test('validates every event fixture against its exact property set', () {
      for (final entry in validEventProperties.entries) {
        expect(
          validateAnalyticsEvent(entry.key, {...common, ...entry.value}).valid,
          isTrue,
          reason: entry.key,
        );
      }
    });

    test('accepts the final diagnostic CTA landing location', () {
      expect(
        validateAnalyticsEvent('landing_diagnostic_cta_clicked', {
          ...common,
          'page_view_id': 'ISEhISEhISEhISEhISEhIQ',
          'cta_location': 'final',
        }).valid,
        isTrue,
      );
    });

    test('accepts a flat allowlisted event and rejects unknown names', () {
      expect(
        validateAnalyticsEvent('landing_viewed', {
          ...common,
          'page_view_id': 'ISEhISEhISEhISEhISEhIQ',
        }).valid,
        isTrue,
      );
      expect(
        validateAnalyticsEvent('landing_opened', common).code,
        AnalyticsValidationCode.unknownEvent,
      );
      expect(
        validateAnalyticsEvent('landing_viewed', {
          ...common,
          'page_view_id': 'ISEhISEhISEhISEhISEhIQ',
          'experiment_bucket': 'invented',
        }).code,
        AnalyticsValidationCode.unknownProperty,
      );
    });

    for (final entry in const {
      'email': 'person@example.com',
      'github_handle': 'octocat',
      'prompt': 'explain this code',
      'answer': 'raw diagnostic answer',
      'guest_token': 'secret',
      'context_snapshot': 'raw snapshot',
    }.entries) {
      test('rejects banned property ${entry.key}', () {
        expect(
          validateAnalyticsEvent('landing_viewed', {
            ...common,
            'page_view_id': 'ISEhISEhISEhISEhISEhIQ',
            entry.key: entry.value,
          }).code,
          AnalyticsValidationCode.bannedProperty,
        );
      });
    }

    test('rejects nested values before delivery', () {
      for (final nested in <Object>[
        {'nested': true},
        ['nested'],
      ]) {
        expect(
          validateAnalyticsEvent('landing_viewed', {
            ...common,
            'page_view_id': nested,
          }).code,
          AnalyticsValidationCode.nestedProperty,
        );
      }
    });

    test('requires the exact version and common properties', () {
      expect(
        validateAnalyticsEvent('landing_viewed', {
          ...common,
          'contract_version': 'mission-spine.analytics.v0',
          'page_view_id': 'ISEhISEhISEhISEhISEhIQ',
        }).code,
        AnalyticsValidationCode.contractVersionMismatch,
      );
      expect(
        validateAnalyticsEvent('landing_viewed', {
          for (final entry in common.entries)
            if (entry.key != 'session_id') entry.key: entry.value,
          'page_view_id': 'ISEhISEhISEhISEhISEhIQ',
        }).code,
        AnalyticsValidationCode.missingProperty,
      );
    });

    for (final userId in ['octocat', 'person@example.com', '홍길동', '0', '-1']) {
      test('rejects non-platform user_id $userId', () {
        expect(
          validateAnalyticsEvent('path_generated', {
            ...common,
            'path_id': 21,
            'assessment_id': 11,
            'user_id': userId,
          }).code,
          AnalyticsValidationCode.invalidIdentifier,
        );
      });
    }

    test(
      'rejects unbounded enums, zero counters, false triggers and loose dates',
      () {
        expect(
          validateAnalyticsEvent('diagnostic_started', {
            ...common,
            'track': 'raw answer text',
            'assessment_id': 11,
          }).code,
          AnalyticsValidationCode.invalidPropertyValue,
        );
        expect(
          validateAnalyticsEvent('first_mission_started', {
            ...common,
            'user_id': '101',
            'path_id': 21,
            'week_num': 0,
            'task_id': 31,
            'first_open': false,
          }).code,
          AnalyticsValidationCode.invalidPropertyValue,
        );
        expect(
          validateAnalyticsEvent('landing_viewed', {
            ...common,
            'occurred_at': 'August 15, 2026',
            'page_view_id': 'ISEhISEhISEhISEhISEhIQ',
          }).code,
          AnalyticsValidationCode.invalidPropertyValue,
        );
        expect(
          validateAnalyticsEvent('landing_viewed', {
            ...common,
            'occurred_at': '2026-99-99T99:99:99.999Z',
            'page_view_id': 'ISEhISEhISEhISEhISEhIQ',
          }).code,
          AnalyticsValidationCode.invalidPropertyValue,
        );
      },
    );

    test('rejects zero or negative approved context counts', () {
      final properties = <String, Object?>{
        ...common,
        ...validEventProperties['contextual_review_viewed']!,
        'approved_context_field_count': 0,
      };
      expect(
        validateAnalyticsEvent('contextual_review_viewed', properties).code,
        AnalyticsValidationCode.invalidPropertyValue,
      );
      expect(
        validateAnalyticsEvent('contextual_review_viewed', {
          ...properties,
          'approved_context_field_count': -1,
        }).code,
        AnalyticsValidationCode.invalidPropertyValue,
      );
    });

    for (final vector in const [
      ('path_generated', 'path_id'),
      ('diagnostic_completed', 'duration_ms'),
      ('first_mission_started', 'week_num'),
      ('contextual_review_viewed', 'approved_context_field_count'),
    ]) {
      test(
        'keeps ${vector.$1}.${vector.$2} within the cross-runtime safe integer range',
        () {
          final properties = <String, Object?>{
            ...common,
            ...validEventProperties[vector.$1]!,
          };
          expect(
            validateAnalyticsEvent(vector.$1, {
              ...properties,
              vector.$2: 9007199254740991,
            }).valid,
            isTrue,
          );
          expect(
            validateAnalyticsEvent(vector.$1, {
              ...properties,
              vector.$2: 9007199254740992,
            }).valid,
            isFalse,
          );
        },
      );
    }
  });
}
