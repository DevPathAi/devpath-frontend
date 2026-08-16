import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Docker compiles version, mission flag and analytics contract args', () {
    final dockerfile = File('Dockerfile').readAsStringSync();

    for (final arg in [
      'APP_VERSION',
      'MISSION_SPINE_ENABLED',
      'ANALYTICS_CONTRACT_VERSION',
      'ANALYTICS_ENVIRONMENT',
    ]) {
      expect(dockerfile, contains('ARG $arg='));
      expect(dockerfile, contains('--dart-define=$arg=\${$arg}'));
      expect(dockerfile, contains('ai.leva.${arg.toLowerCase()}'));
    }
  });

  test(
    'CI builds distinct OFF/ON identities without publishing or deploying them',
    () {
      final workflow = File(
        '../../.github/workflows/ci.yml',
      ).readAsStringSync();
      final start = workflow.indexOf('  web-image-config-contract:');
      final end = workflow.indexOf('\n  web-image:', start + 1);
      final contractJob = start >= 0 && end > start
          ? workflow.substring(start, end)
          : null;

      expect(contractJob, isNotNull);
      expect(contractJob, contains('identity: off'));
      expect(contractJob, contains('identity: on'));
      expect(
        contractJob,
        contains('MISSION_SPINE_ENABLED=\${{ matrix.enabled }}'),
      );
      expect(contractJob, contains('APP_VERSION=\${{ github.sha }}'));
      expect(
        contractJob,
        contains('ANALYTICS_CONTRACT_VERSION=mission-spine.analytics.v1'),
      );
      expect(contractJob, contains('ANALYTICS_ENVIRONMENT=production'));
      expect(contractJob, contains('push: false'));
      expect(
        contractJob,
        contains(
          'outputs: type=oci,dest=\${{ runner.temp }}/leva-web-\${{ matrix.identity }}.tar',
        ),
      );
      expect(contractJob, contains('sha256sum "\${ARTIFACT_PATH}"'));
      expect(contractJob, contains('"app_version":"%s"'));
      expect(contractJob, contains('"mission_spine_enabled":%s'));
      expect(contractJob, contains('"analytics_contract_version":"%s"'));
      expect(
        contractJob,
        contains(
          'actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02',
        ),
      );
      expect(
        contractJob,
        contains(
          'name: leva-web-\${{ github.sha }}-mission-\${{ matrix.identity }}',
        ),
      );
      expect(
        contractJob,
        contains(':\${{ github.sha }}-mission-\${{ matrix.identity }}'),
      );
      expect(contractJob, isNot(contains('kustomize')));
      expect(contractJob, isNot(contains('gitops')));
      expect(
        File('Dockerfile').readAsStringSync(),
        contains(
          'test "\${ANALYTICS_CONTRACT_VERSION}" = "mission-spine.analytics.v1"',
        ),
      );
    },
  );

  test('web startup cleans the handoff before Flutter router startup', () {
    final main = File('lib/main.dart').readAsStringSync();
    final webHandoff = File(
      'lib/src/analytics/journey_handoff_web.dart',
    ).readAsStringSync();

    expect(
      main.indexOf('captureJourneyHandoffFromVisibleUrl()'),
      lessThan(main.indexOf('runApp(')),
    );
    expect(webHandoff, contains('window.sessionStorage'));
    expect(webHandoff, contains('history.replaceState'));
  });
}
