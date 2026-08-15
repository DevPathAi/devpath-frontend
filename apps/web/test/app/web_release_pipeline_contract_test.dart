import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String workflow;

  setUpAll(() {
    workflow = File(
      '../../.github/workflows/ci.yml',
    ).readAsStringSync().replaceAll('\r\n', '\n');
  });

  String job(String name, {required String nextJob}) {
    final start = workflow.indexOf('  $name:');
    final end = workflow.indexOf('\n  $nextJob:', start + 1);

    expect(start, greaterThanOrEqualTo(0), reason: '$name job is required');
    expect(end, greaterThan(start), reason: '$nextJob must follow $name');
    return workflow.substring(start, end);
  }

  String stepRun(String name) {
    final stepStart = workflow.indexOf('      - name: $name');
    final runMarker = '        run: |\n';
    final runStart = workflow.indexOf(runMarker, stepStart);
    final nextStep = workflow.indexOf(
      '\n      - ',
      runStart + runMarker.length,
    );

    expect(
      stepStart,
      greaterThanOrEqualTo(0),
      reason: '$name step is required',
    );
    expect(
      runStart,
      greaterThan(stepStart),
      reason: '$name must have a run block',
    );
    expect(
      nextStep,
      greaterThan(runStart),
      reason: '$name must precede a step',
    );

    return workflow
        .substring(runStart + runMarker.length, nextStep)
        .replaceAll('\r', '')
        .split('\n')
        .map(
          (line) => line.startsWith('          ') ? line.substring(10) : line,
        )
        .join('\n');
  }

  Future<ProcessResult> runImmutableBind(String candidateConfigDigest) async {
    final bindScript = stepRun(
      'Bind immutable tag once',
    ).replaceAll(r'${{ matrix.identity }}', 'off');
    final harness =
        r'''
set -u
source_sha=0123456789abcdef0123456789abcdef01234567
registry_digest=sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
registry_config_digest=sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
github_output="$(mktemp)"
mutation_log="$(mktemp)"
trap 'rm -f "${github_output}" "${mutation_log}"' EXIT
export TAG_REFERENCE="ghcr.io/devpathai/devpath-web:${source_sha}-mission-off"
export IMAGE_REPOSITORY=ghcr.io/devpathai/devpath-web
export CANDIDATE_REFERENCE="leva-web-candidate:${source_sha}-mission-off"
export CANDIDATE_CONFIG_DIGEST=__CANDIDATE_CONFIG_DIGEST__
export PREFLIGHT_STATE=present
export PREFLIGHT_DIGEST="${registry_digest}"
export PREFLIGHT_CONFIG_DIGEST="${registry_config_digest}"
export SOURCE_SHA="${source_sha}"
export MISSION_SPINE_ENABLED=false
export ANALYTICS_CONTRACT_VERSION=mission-spine.analytics.v1
export ANALYTICS_ENVIRONMENT=production
export RUNNER_TEMP=/tmp
export GITHUB_OUTPUT="${github_output}"

docker() {
  if test "$1" = "tag" || test "$1" = "push"; then
    printf '%s\n' "$*" >>"${mutation_log}"
    return 97
  fi
  if test "$1 $2 $3" != "buildx imagetools inspect"; then
    echo "Unexpected docker command: $*" >&2
    return 98
  fi
  case "$*" in
    *"--raw"*)
      jq -nc --arg digest "${registry_config_digest}" \
        '{schemaVersion: 2, config: {digest: $digest}}'
      ;;
    *"{{json .Image}}"*)
      jq -nc \
        --arg sha "${source_sha}" \
        '{
          architecture: "amd64",
          os: "linux",
          config: {Labels: {
            "org.opencontainers.image.revision": $sha,
            "ai.leva.app_version": $sha,
            "ai.leva.mission_spine_enabled": "false",
            "ai.leva.analytics_contract_version": "mission-spine.analytics.v1",
            "ai.leva.analytics_environment": "production"
          }}
        }'
      ;;
    *"{{.Manifest.Digest}}"*)
      printf '%s\n' "${registry_digest}"
      ;;
    *)
      echo "Unexpected imagetools arguments: $*" >&2
      return 99
      ;;
  esac
}

set +e
(
''' +
        bindScript +
        r'''
)
status=$?
set -e
printf '__GITHUB_OUTPUT__\n'
cat "${github_output}"
printf '__MUTATIONS__\n'
cat "${mutation_log}"
exit "${status}"
''';

    final process = await Process.start('bash', ['-s']);
    process.stdin.write(
      harness.replaceAll('__CANDIDATE_CONFIG_DIGEST__', candidateConfigDigest),
    );
    await process.stdin.close();
    final stdout = await process.stdout.transform(utf8.decoder).join();
    final stderr = await process.stderr.transform(utf8.decoder).join();
    final exitCode = await process.exitCode;
    return ProcessResult(process.pid, exitCode, stdout, stderr);
  }

  String mutationLog(ProcessResult result) =>
      (result.stdout as String).split('__MUTATIONS__\n').last.trim();

  test(
    'main publishes distinct immutable mission OFF and ON registry images',
    () {
      final publishJob = job(
        'web-image',
        nextJob: 'web-image-release-contract',
      );

      expect(publishJob, contains("if: github.ref == 'refs/heads/main'"));
      expect(
        publishJob,
        contains('group: web-image-\${{ github.sha }}-\${{ matrix.identity }}'),
      );
      expect(publishJob, contains('cancel-in-progress: false'));
      expect(publishJob, contains('identity: off'));
      expect(publishJob, contains("enabled: 'false'"));
      expect(publishJob, contains('identity: on'));
      expect(publishJob, contains("enabled: 'true'"));
      expect(publishJob, contains('id: candidate'));
      expect(publishJob, contains('load: true'));
      expect(publishJob, contains('push: false'));
      expect(publishJob, contains('docker push "\${tag_reference}"'));
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

  test('an immutable tag is reused or rejected before any tag mutation', () {
    final publishJob = job('web-image', nextJob: 'web-image-release-contract');
    final preflight = publishJob.indexOf(
      'name: Inspect immutable tag before build',
    );
    final candidateBuild = publishJob.indexOf('id: candidate');
    final bind = publishJob.indexOf('name: Bind immutable tag once');
    final tagMutation = publishJob.indexOf('docker push "\${tag_reference}"');

    expect(preflight, greaterThanOrEqualTo(0));
    expect(candidateBuild, greaterThan(preflight));
    expect(bind, greaterThan(candidateBuild));
    expect(tagMutation, greaterThan(bind));
    expect(publishJob, contains('id: immutable-tag'));
    expect(publishJob, contains('id: candidate-metadata'));
    expect(
      publishJob,
      contains(
        'test "\${observed_config_digest}" = "\${candidate_config_digest}"',
      ),
    );
    expect(
      publishJob,
      contains(
        'raw_manifest_json="\$(docker buildx imagetools inspect "\${exact_reference}" --raw)"',
      ),
    );
    expect(
      publishJob,
      contains(
        'observed_config_digest="\$(jq -er \'.config.digest\' <<<"\${raw_manifest_json}")"',
      ),
    );
    expect(publishJob, contains('Refusing to overwrite immutable tag'));
    expect(
      publishJob.indexOf('Refusing to overwrite immutable tag'),
      lessThan(tagMutation),
    );
    expect(
      publishJob,
      contains('docker buildx imagetools inspect "\${tag_reference}"'),
    );
  });

  test('the same immutable candidate is reused without a tag mutation', () async {
    const matchingConfig =
        'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    final result = await runImmutableBind(matchingConfig);

    expect(result.exitCode, 0, reason: result.stderr as String);
    expect(result.stdout as String, contains('mode=reused'));
    expect(mutationLog(result), isEmpty);
  });

  test('a different candidate is rejected before a tag mutation', () async {
    const driftedConfig =
        'sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
    final result = await runImmutableBind(driftedConfig);

    expect(result.exitCode, isNot(0));
    expect(result.stderr as String, contains('candidate digest drift'));
    expect(mutationLog(result), isEmpty);
  });

  test('main records and compares registry digests using safe evidence only', () {
    final publishJob = job('web-image', nextJob: 'web-image-release-contract');
    final verifyJob = job('web-image-release-contract', nextJob: 'admin-image');

    expect(
      publishJob,
      contains('REGISTRY_DIGEST: \${{ steps.bind-tag.outputs.digest }}'),
    );
    expect(
      publishJob,
      contains(
        'docker buildx imagetools inspect "\${exact_reference}" --format \'{{json .Image}}\'',
      ),
    );
    expect(
      publishJob,
      contains(
        'docker buildx imagetools inspect "\${tag_reference}" --format \'{{.Manifest.Digest}}\'',
      ),
    );
    expect(
      publishJob,
      contains('test "\${tag_digest}" = "\${registry_digest}"'),
    );
    expect(publishJob, contains('--arg app_version "\${actual_app_version}"'));
    expect(
      publishJob,
      contains('--argjson mission_spine_enabled "\${actual_mission_enabled}"'),
    );
    expect(publishJob, isNot(contains('--arg app_version "\${SOURCE_SHA}"')));
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
    expect(verifyJob, contains('continue-on-error: true'));
    expect(verifyJob, contains('!cancelled()'));
    expect(
      verifyJob,
      contains('WEB_IMAGE_RESULT: \${{ needs.web-image.result }}'),
    );
    expect(verifyJob, contains('test "\${WEB_IMAGE_RESULT}" = "success"'));
    expect(
      verifyJob,
      contains('DOWNLOAD_OUTCOME: \${{ steps.evidence-download.outcome }}'),
    );
    expect(verifyJob, contains('test "\${DOWNLOAD_OUTCOME}" = "success"'));
    expect(verifyJob, contains('test -s "\${off_evidence}"'));
    expect(verifyJob, contains('test -s "\${on_evidence}"'));
    expect(verifyJob, contains("off_digest=\"\$(jq -r '.image_digest'"));
    expect(verifyJob, contains("on_digest=\"\$(jq -r '.image_digest'"));
    expect(verifyJob, contains('test "\${off_digest}" != "\${on_digest}"'));
    expect(verifyJob, contains("mission_spine_enabled == false"));
    expect(verifyJob, contains("mission_spine_enabled == true"));
    expect(
      verifyJob,
      contains('.image_labels["org.opencontainers.image.revision"] == \$sha'),
    );
    expect(
      verifyJob,
      contains(
        '.image_labels["ai.leva.analytics_environment"] == "production"',
      ),
    );
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
