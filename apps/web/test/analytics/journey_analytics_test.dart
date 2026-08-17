import 'package:devpath_web/src/analytics/journey_analytics.dart';
import 'package:flutter_test/flutter_test.dart';

class _SpySdk implements JourneyAnalyticsSdk {
  final captures = <(String, Map<String, Object?>)>[];
  final identities = <String>[];
  var resets = 0;
  Object? captureFailure;

  @override
  Future<void> capture(String event, Map<String, Object?> properties) async {
    if (captureFailure case final failure?) throw failure;
    captures.add((event, properties));
  }

  @override
  Future<void> identify(String userId) async {
    identities.add(userId);
  }

  @override
  Future<void> reset() async {
    resets++;
  }
}

class _SyncSdk implements JourneyAnalyticsSdk {
  var captures = 0;

  @override
  void capture(String event, Map<String, Object?> properties) => captures++;

  @override
  void identify(String userId) {}

  @override
  void reset() {}
}

final context = JourneyAnalyticsContext(
  environment: 'production',
  appVersion: 'abc123',
  sessionId: 'AQIDBAUGBwgJCgsMDQ4PEA',
  journeyId: 'EREREREREREREREREREREQ',
  now: () => DateTime.utc(2026, 8, 15, 10),
);

void main() {
  group('JourneyAnalyticsAdapter', () {
    test('starts opted out and makes no SDK calls', () {
      final sdk = _SpySdk();
      final analytics = JourneyAnalyticsAdapter(sdk: sdk, context: context);

      expect(
        analytics.capture('landing_viewed', const {
          'page_view_id': 'ISEhISEhISEhISEhISEhIQ',
        }),
        AnalyticsCaptureStatus.optedOut,
      );
      expect(analytics.identify('101'), isFalse);
      analytics.reset();

      expect(sdk.captures, isEmpty);
      expect(sdk.identities, isEmpty);
      expect(sdk.resets, 0);
    });

    test('rejects unknown, PII and nested values before scheduling SDK', () {
      final sdk = _SpySdk();
      final scheduled = <void Function()>[];
      final analytics = JourneyAnalyticsAdapter(
        sdk: sdk,
        context: context,
        optedOut: false,
        schedule: scheduled.add,
      );

      for (final properties in <Map<String, Object?>>[
        {'page_view_id': 'ISEhISEhISEhISEhISEhIQ', 'unknown': true},
        {
          'page_view_id': 'ISEhISEhISEhISEhISEhIQ',
          'email': 'person@example.com',
        },
        {
          'page_view_id': {'nested': true},
        },
      ]) {
        expect(
          analytics.capture('landing_viewed', properties),
          AnalyticsCaptureStatus.rejected,
        );
      }
      expect(scheduled, isEmpty);
      expect(sdk.captures, isEmpty);
    });

    for (final property in const [
      'contract_version',
      'occurred_at',
      'environment',
      'app_version',
      'session_id',
      'journey_id',
    ]) {
      test('rejects caller override of adapter-owned $property', () {
        final sdk = _SpySdk();
        final scheduled = <void Function()>[];
        final analytics = JourneyAnalyticsAdapter(
          sdk: sdk,
          context: context,
          optedOut: false,
          schedule: scheduled.add,
        );

        expect(
          analytics.capture('landing_viewed', {
            'page_view_id': 'ISEhISEhISEhISEhISEhIQ',
            property: property == 'occurred_at'
                ? '2026-08-15T11:00:00.000Z'
                : 'attacker-controlled',
          }),
          AnalyticsCaptureStatus.rejected,
        );
        expect(scheduled, isEmpty);
        expect(sdk.captures, isEmpty);
      });
    }

    test(
      'does not emit contextual review without an approved context field',
      () {
        final sdk = _SpySdk();
        final scheduled = <void Function()>[];
        final analytics = JourneyAnalyticsAdapter(
          sdk: sdk,
          context: context,
          optedOut: false,
          schedule: scheduled.add,
        );

        expect(
          analytics.capture('contextual_review_viewed', const {
            'user_id': '101',
            'task_id': 31,
            'review_id': 61,
            'approved_context_field_count': 0,
            'next_action_outcome': 'next_mission',
            'first_view': true,
          }),
          AnalyticsCaptureStatus.rejected,
        );
        expect(scheduled, isEmpty);
        expect(sdk.captures, isEmpty);
      },
    );

    test('deduplicates using the event contract', () {
      final sdk = _SpySdk();
      final analytics = JourneyAnalyticsAdapter(
        sdk: sdk,
        context: context,
        optedOut: false,
        schedule: (work) => work(),
      );

      expect(
        analytics.capture('landing_viewed', const {
          'page_view_id': 'ISEhISEhISEhISEhISEhIQ',
        }),
        AnalyticsCaptureStatus.accepted,
      );
      expect(
        analytics.capture('landing_viewed', const {
          'page_view_id': 'ISEhISEhISEhISEhISEhIQ',
        }),
        AnalyticsCaptureStatus.duplicate,
      );
      expect(sdk.captures, hasLength(1));
    });

    test('SDK failure is non-blocking', () {
      final sdk = _SpySdk()..captureFailure = StateError('blocked');
      final analytics = JourneyAnalyticsAdapter(
        sdk: sdk,
        context: context,
        optedOut: false,
        schedule: (work) => work(),
      );

      expect(
        () => analytics.capture('landing_viewed', const {
          'page_view_id': 'ISEhISEhISEhISEhISEhIQ',
        }),
        returnsNormally,
      );
    });

    test('accepts synchronous SDK implementations behind the same adapter', () {
      final sdk = _SyncSdk();
      final analytics = JourneyAnalyticsAdapter(
        sdk: sdk,
        context: context,
        optedOut: false,
        schedule: (work) => work(),
      );

      expect(
        analytics.capture('landing_viewed', const {
          'page_view_id': 'ISEhISEhISEhISEhISEhIQ',
        }),
        AnalyticsCaptureStatus.accepted,
      );
      expect(sdk.captures, 1);
    });

    test('explicit opt-in, opaque identify, reset and test exclusion', () {
      final sdk = _SpySdk();
      final analytics = JourneyAnalyticsAdapter(
        sdk: sdk,
        context: context,
        schedule: (work) => work(),
      );

      analytics.setOptedOut(false);
      expect(analytics.identify('101'), isTrue);
      expect(analytics.identify('person@example.com'), isFalse);
      expect(analytics.identify('octocat'), isFalse);
      expect(analytics.identify('홍길동'), isFalse);
      analytics.reset();
      expect(sdk.identities, ['101']);
      expect(sdk.resets, 1);

      final excluded = JourneyAnalyticsAdapter(
        sdk: sdk,
        context: JourneyAnalyticsContext(
          environment: 'test',
          appVersion: 'abc123',
          sessionId: 'AQIDBAUGBwgJCgsMDQ4PEA',
          journeyId: 'EREREREREREREREREREREQ',
        ),
        optedOut: false,
        schedule: (work) => work(),
      );
      expect(
        excluded.capture('landing_viewed', const {
          'page_view_id': 'ISEhISEhISEhISEhISEhIQ',
        }),
        AnalyticsCaptureStatus.excluded,
      );
    });

    test(
      'retains auth identity in memory and identifies only after permission',
      () {
        final sdk = _SpySdk();
        final analytics = JourneyAnalyticsAdapter(
          sdk: sdk,
          context: context,
          schedule: (work) => work(),
        );

        expect(analytics.identify('101'), isFalse);
        expect(sdk.identities, isEmpty);
        analytics.setOptedOut(false);
        expect(sdk.identities, ['101']);

        analytics.setOptedOut(true);
        expect(sdk.resets, 1);
        analytics.setOptedOut(false);
        expect(sdk.identities, ['101', '101']);
      },
    );

    test('retains internal exclusion across pre-permission transition', () {
      final sdk = _SpySdk();
      final analytics = JourneyAnalyticsAdapter(
        sdk: sdk,
        context: context,
        isInternalUser: (userId) => userId == '999',
        schedule: (work) => work(),
      );

      expect(analytics.identify('999'), isFalse);
      analytics.setOptedOut(false);
      expect(
        analytics.capture('landing_viewed', const {
          'page_view_id': 'ISEhISEhISEhISEhISEhIQ',
        }),
        AnalyticsCaptureStatus.excluded,
      );
      expect(sdk.identities, isEmpty);
      expect(sdk.captures, isEmpty);
    });

    test(
      'exposes automated-UA, dev-build and internal-account exclusion seams',
      () {
        expect(
          shouldExcludeAnalyticsTraffic(
            environment: 'production',
            appVersion: 'abc123',
            userAgent: 'Playwright',
          ),
          isTrue,
        );
        expect(
          shouldExcludeAnalyticsTraffic(
            environment: 'development',
            appVersion: 'abc123',
          ),
          isTrue,
        );
        expect(
          shouldExcludeAnalyticsTraffic(
            environment: 'production',
            appVersion: 'dev',
          ),
          isTrue,
        );

        final sdk = _SpySdk();
        final analytics = JourneyAnalyticsAdapter(
          sdk: sdk,
          context: context,
          optedOut: false,
          isInternalUser: (userId) => userId == '999',
          schedule: (work) => work(),
        );
        expect(analytics.identify('999'), isFalse);
        expect(
          analytics.capture('landing_viewed', const {
            'page_view_id': 'ISEhISEhISEhISEhISEhIQ',
          }),
          AnalyticsCaptureStatus.excluded,
        );
        expect(sdk.captures, isEmpty);
      },
    );

    test(
      'internal/account switches reset vendor identity without sticky exclusion',
      () {
        final sdk = _SpySdk();
        final analytics = JourneyAnalyticsAdapter(
          sdk: sdk,
          context: context,
          optedOut: false,
          isInternalUser: (userId) => userId == '999',
          schedule: (work) => work(),
        );

        expect(analytics.identify('101'), isTrue);
        expect(analytics.identify('999'), isFalse);
        expect(sdk.resets, 1);
        analytics.reset();
        expect(analytics.identify('102'), isTrue);
        expect(sdk.identities, ['101', '102']);

        analytics.setOptedOut(true);
        expect(sdk.resets, 2);
      },
    );
  });
}
