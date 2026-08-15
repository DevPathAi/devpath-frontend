import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String workflow;

  setUpAll(() {
    workflow = File('../../.github/workflows/ci.yml').readAsStringSync();
  });

  String job(String name, {required String nextJob}) {
    final start = workflow.indexOf('  $name:');
    final end = workflow.indexOf('\n  $nextJob:', start + 1);

    expect(start, greaterThanOrEqualTo(0), reason: '$name job is required');
    expect(end, greaterThan(start), reason: '$nextJob must follow $name');
    return workflow.substring(start, end);
  }

  test(
    'main publishes distinct immutable mission OFF and ON registry images',
    () {
      final publishJob = job(
        'web-image',
        nextJob: 'web-image-release-contract',
      );

      expect(publishJob, contains("if: github.ref == 'refs/heads/main'"));
      expect(publishJob, contains('identity: off'));
      expect(publishJob, contains("enabled: 'false'"));
      expect(publishJob, contains('identity: on'));
      expect(publishJob, contains("enabled: 'true'"));
      expect(publishJob, contains('id: publish'));
      expect(publishJob, contains('push: true'));
      expect(
        publishJob,
        contains(
          'ghcr.io/devpathai/devpath-web:\${{ github.sha }}-mission-\${{ matrix.identity }}',
        ),
      );
      expect(
        publishJob,
        contains('MISSION_SPINE_ENABLED=\${{ matrix.enabled }}'),
      );
      expect(publishJob, contains('APP_VERSION=\${{ github.sha }}'));
      expect(
        publishJob,
        contains('ANALYTICS_CONTRACT_VERSION=mission-spine.analytics.v1'),
      );

      for (final label in [
        'ai.leva.app_version=\${{ github.sha }}',
        'ai.leva.mission_spine_enabled=\${{ matrix.enabled }}',
        'ai.leva.analytics_contract_version=mission-spine.analytics.v1',
      ]) {
        expect(publishJob, contains(label));
      }

      expect(
        publishJob,
        isNot(
          matches(
            RegExp(
              r'^\s*ghcr\.io/devpathai/devpath-web:\$\{\{ github\.sha \}\}\s*$',
              multiLine: true,
            ),
          ),
        ),
      );
      expect(publishJob, isNot(contains('ghcr.io/devpathai/devpath-web:main')));
    },
  );

  test('main records and compares registry digests using safe evidence only', () {
    final publishJob = job('web-image', nextJob: 'web-image-release-contract');
    final verifyJob = job('web-image-release-contract', nextJob: 'admin-image');

    expect(
      publishJob,
      contains('REGISTRY_DIGEST: \${{ steps.publish.outputs.digest }}'),
    );
    expect(
      publishJob,
      contains('"schema_version": "mission-spine.web-artifact.v1"'),
    );
    expect(publishJob, contains('"source_sha": \$source_sha'));
    expect(publishJob, contains('"image_digest": \$image_digest'));
    expect(publishJob, contains('"compiled_config":'));
    expect(publishJob, contains('actions/upload-artifact@v4'));
    expect(
      publishJob,
      contains(
        'name: leva-web-\${{ github.sha }}-mission-\${{ matrix.identity }}-registry-evidence',
      ),
    );
    expect(publishJob, isNot(contains('sha256sum')));
    expect(publishJob, isNot(contains('to_entries')));
    expect(publishJob, isNot(contains('env |')));
    expect(publishJob, isNot(contains('"api_base_url"')));
    expect(publishJob, isNot(contains('"token"')));
    expect(publishJob, isNot(contains('"actor"')));

    expect(verifyJob, contains('actions/download-artifact@v5'));
    expect(verifyJob, contains('merge-multiple: true'));
    expect(verifyJob, contains("off_digest=\"\$(jq -r '.image_digest'"));
    expect(verifyJob, contains("on_digest=\"\$(jq -r '.image_digest'"));
    expect(verifyJob, contains('test "\${off_digest}" != "\${on_digest}"'));
    expect(verifyJob, contains("mission_spine_enabled == false"));
    expect(verifyJob, contains("mission_spine_enabled == true"));
  });

  test('web publication cannot deploy or mutate GitOps state', () {
    final webReleaseLane = job('web-image', nextJob: 'admin-image');

    expect(workflow, isNot(contains('\n  web-deploy:')));
    for (final forbidden in [
      'devpath-gitops',
      'GITOPS_APP_ID',
      'GITOPS_APP_PRIVATE_KEY',
      'actions/create-github-app-token',
      'kustomize',
      'git push',
    ]) {
      expect(webReleaseLane, isNot(contains(forbidden)));
    }
  });
}
