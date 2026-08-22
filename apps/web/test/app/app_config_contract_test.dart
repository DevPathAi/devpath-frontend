import 'package:devpath_web/src/analytics/analytics_contract.dart';
import 'package:devpath_web/src/app/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'compiled Mission Spine config defaults OFF with a versioned identity',
    () {
      final config = AppConfig.fromEnvironment();

      expect(config.appVersion, 'dev');
      expect(config.missionSpineEnabled, isFalse);
      expect(config.analyticsContractVersion, analyticsContractVersion);
      expect(config.analyticsEnvironment, 'test');
      expect(
        config.buildIdentity,
        'dev-mission-off-analytics-mission-spine.analytics.v1-env-test',
      );
    },
  );

  test(
    'OFF and ON from one app version have distinct immutable identities',
    () {
      const off = AppConfig(
        baseUrl: 'https://api.test',
        useMock: false,
        appVersion: 'same-sha',
        missionSpineEnabled: false,
        analyticsContractVersion: analyticsContractVersion,
        analyticsEnvironment: 'production',
      );
      const on = AppConfig(
        baseUrl: 'https://api.test',
        useMock: false,
        appVersion: 'same-sha',
        missionSpineEnabled: true,
        analyticsContractVersion: analyticsContractVersion,
        analyticsEnvironment: 'production',
      );

      expect(off.buildIdentity, isNot(on.buildIdentity));
      expect(off.buildIdentity, contains('-mission-off-'));
      expect(on.buildIdentity, contains('-mission-on-'));
    },
  );
}
