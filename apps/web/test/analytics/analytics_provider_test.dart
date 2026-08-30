import 'package:devpath_web/src/analytics/journey_analytics.dart';
import 'package:devpath_web/src/analytics/journey_handoff.dart';
import 'package:devpath_web/src/analytics/release_analytics.dart';
import 'package:devpath_web/src/app/app_config.dart';
import 'package:devpath_web/src/providers/api_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final class _CaptureSpySdk implements JourneyAnalyticsSdk {
  final captures = <String>[];

  @override
  void capture(String event, Map<String, Object?> properties) {
    captures.add(event);
  }

  @override
  void identify(String userId) {}

  @override
  void reset() {}
}

class _ThrowingStore implements JourneyIdStore {
  @override
  void clear() => throw StateError('storage denied');

  @override
  String? read() => throw StateError('storage denied');

  @override
  void write(String journeyId) => throw StateError('storage denied');
}

void main() {
  test(
    'session and journey IDs survive provider/container recreation independently',
    () {
      final journeyStore = MemoryJourneyIdStore();
      final sessionStore = MemoryJourneyIdStore();

      JourneyAnalytics readWithFreshContainer() {
        final container = ProviderContainer(
          overrides: [
            journeyIdStoreProvider.overrideWithValue(journeyStore),
            analyticsSessionIdStoreProvider.overrideWithValue(sessionStore),
            analyticsIdGeneratorProvider.overrideWithValue(
              () => journeyStore.read() == null
                  ? 'AQIDBAUGBwgJCgsMDQ4PEA'
                  : 'EREREREREREREREREREREQ',
            ),
          ],
        );
        addTearDown(container.dispose);
        return container.read(journeyAnalyticsProvider);
      }

      expect(readWithFreshContainer(), isA<JourneyAnalyticsAdapter>());
      final firstJourney = journeyStore.read();
      final firstSession = sessionStore.read();
      expect(readWithFreshContainer(), isA<JourneyAnalyticsAdapter>());
      expect(journeyStore.read(), firstJourney);
      expect(sessionStore.read(), firstSession);
      expect(firstJourney, isNot(firstSession));
    },
  );

  test('storage/random denial falls back to an opted-out no-op', () {
    final container = ProviderContainer(
      overrides: [
        journeyIdStoreProvider.overrideWithValue(_ThrowingStore()),
        analyticsSessionIdStoreProvider.overrideWithValue(_ThrowingStore()),
        analyticsIdGeneratorProvider.overrideWithValue(
          () => throw StateError('secure random denied'),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(() => container.read(journeyAnalyticsProvider), returnsNormally);
    expect(
      container.read(journeyAnalyticsProvider).capture('landing_viewed', const {
        'page_view_id': 'ISEhISEhISEhISEhISEhIQ',
      }),
      AnalyticsCaptureStatus.optedOut,
    );
  });

  test('compiled analytics contract mismatch remains disabled', () {
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          const AppConfig(
            baseUrl: 'https://api.test',
            useMock: false,
            appVersion: 'abc123',
            analyticsContractVersion: 'mission-spine.analytics.v0',
            analyticsEnvironment: 'production',
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(
      container.read(journeyAnalyticsProvider).capture('landing_viewed', const {
        'page_view_id': 'ISEhISEhISEhISEhISEhIQ',
      }),
      AnalyticsCaptureStatus.optedOut,
    );
  });

  test('production provider wires the browser UA into automated exclusion', () {
    final journeyStore = MemoryJourneyIdStore()
      ..write('AQIDBAUGBwgJCgsMDQ4PEA');
    final sessionStore = MemoryJourneyIdStore()
      ..write('EREREREREREREREREREREQ');
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          const AppConfig(
            baseUrl: 'https://api.test',
            useMock: false,
            appVersion: 'abc123',
            analyticsEnvironment: 'production',
          ),
        ),
        journeyIdStoreProvider.overrideWithValue(journeyStore),
        analyticsSessionIdStoreProvider.overrideWithValue(sessionStore),
        analyticsUserAgentProvider.overrideWithValue(
          'Mozilla/5.0 HeadlessChrome Playwright',
        ),
      ],
    );
    addTearDown(container.dispose);

    final analytics = container.read(journeyAnalyticsProvider)
      ..setOptedOut(false);
    expect(
      analytics.capture('landing_viewed', const {
        'page_view_id': 'ISEhISEhISEhISEhISEhIQ',
      }),
      AnalyticsCaptureStatus.excluded,
    );
  });

  test(
    'valid release marker bypasses only the automated browser exclusion',
    () {
      final journeyStore = MemoryJourneyIdStore()
        ..write('AQIDBAUGBwgJCgsMDQ4PEA');
      final sessionStore = MemoryJourneyIdStore()
        ..write('EREREREREREREREREREREQ');
      final marker = parseReleaseAnalyticsMarker('''{
      "schema_version":"mission-spine.release-analytics.v1",
      "permission_url":"https://api.leva.ai.kr/v1/release/browser/analytics-permission",
      "capture_url":"https://analytics-spy.staging.leva.ai.kr/v1/release/browser/analytics-events"
    }''');
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(
              baseUrl: 'https://api.leva.ai.kr',
              useMock: false,
              appVersion: 'abc123',
              analyticsEnvironment: 'production',
            ),
          ),
          journeyIdStoreProvider.overrideWithValue(journeyStore),
          analyticsSessionIdStoreProvider.overrideWithValue(sessionStore),
          analyticsUserAgentProvider.overrideWithValue(
            'Mozilla/5.0 HeadlessChrome Playwright',
          ),
          releaseAnalyticsMarkerProvider.overrideWithValue(marker),
        ],
      );
      addTearDown(container.dispose);

      expect(
        container.read(journeyAnalyticsProvider).capture(
          'landing_viewed',
          const {'page_view_id': 'ISEhISEhISEhISEhISEhIQ'},
        ),
        AnalyticsCaptureStatus.accepted,
      );
    },
  );

  test(
    'release capture starts keepalive delivery before the next event turn',
    () {
      final journeyStore = MemoryJourneyIdStore()
        ..write('AQIDBAUGBwgJCgsMDQ4PEA');
      final sessionStore = MemoryJourneyIdStore()
        ..write('EREREREREREREREREREREQ');
      final marker = parseReleaseAnalyticsMarker('''{
      "schema_version":"mission-spine.release-analytics.v1",
      "permission_url":"https://api.leva.ai.kr/v1/release/browser/analytics-permission",
      "capture_url":"https://analytics-spy.staging.leva.ai.kr/v1/release/browser/analytics-events"
    }''');
      final sdk = _CaptureSpySdk();
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(
              baseUrl: 'https://api.leva.ai.kr',
              useMock: false,
              appVersion: 'abc123',
              analyticsEnvironment: 'production',
            ),
          ),
          journeyIdStoreProvider.overrideWithValue(journeyStore),
          analyticsSessionIdStoreProvider.overrideWithValue(sessionStore),
          analyticsUserAgentProvider.overrideWithValue(
            'Mozilla/5.0 HeadlessChrome Playwright',
          ),
          releaseAnalyticsMarkerProvider.overrideWithValue(marker),
          releaseAnalyticsSdkFactoryProvider.overrideWithValue(
            (marker, dio) => sdk,
          ),
        ],
      );
      addTearDown(container.dispose);

      final analytics = container.read(journeyAnalyticsProvider);
      expect(
        analytics.capture('landing_viewed', const {
          'page_view_id': 'ISEhISEhISEhISEhISEhIQ',
        }),
        AnalyticsCaptureStatus.accepted,
      );
      expect(
        sdk.captures,
        ['landing_viewed'],
        reason: 'a release claim must not outrun SDK queue registration',
      );
    },
  );

  test(
    'production provider exposes an authoritative internal-account seam',
    () {
      final journeyStore = MemoryJourneyIdStore()
        ..write('AQIDBAUGBwgJCgsMDQ4PEA');
      final sessionStore = MemoryJourneyIdStore()
        ..write('EREREREREREREREREREREQ');
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(
              baseUrl: 'https://api.test',
              useMock: false,
              appVersion: 'abc123',
              analyticsEnvironment: 'production',
            ),
          ),
          journeyIdStoreProvider.overrideWithValue(journeyStore),
          analyticsSessionIdStoreProvider.overrideWithValue(sessionStore),
          analyticsUserAgentProvider.overrideWithValue('Mozilla/5.0'),
          analyticsInternalUserPolicyProvider.overrideWithValue(
            (userId) => userId == '999',
          ),
        ],
      );
      addTearDown(container.dispose);

      final analytics = container.read(journeyAnalyticsProvider);
      expect(analytics.identify('999'), isFalse);
      analytics.setOptedOut(false);
      expect(
        analytics.capture('landing_viewed', const {
          'page_view_id': 'ISEhISEhISEhISEhISEhIQ',
        }),
        AnalyticsCaptureStatus.excluded,
      );
    },
  );
}
