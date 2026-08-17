import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final workflowFile = File('../../.github/workflows/ci.yml');
  final publisherFile = File('../../tools/admin_immutable_image.sh');
  final registryWrapperFile = File('../../tools/immutable_registry.sh');

  String job(String workflow, String name) {
    final start = workflow.indexOf('  $name:');
    expect(start, greaterThanOrEqualTo(0), reason: '$name job is required');
    final tail = workflow.substring(start + 1);
    final next = RegExp(
      r'^  [a-z0-9][a-z0-9-]*:$',
      multiLine: true,
    ).firstMatch(tail);
    final end = next == null ? workflow.length : start + 1 + next.start;
    return workflow.substring(start, end);
  }

  Future<ProcessResult> runBind(
    String candidateConfigDigest, {
    bool initiallyAbsent = false,
  }) async {
    final publisher = publisherFile.readAsStringSync().replaceAll('\r\n', '\n');
    final harness =
        r'''
set -u
root_digest=sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
remote_config=sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
github_output="$(mktemp)"
pushed_marker="${github_output}.pushed"
trap 'rm -f "${github_output}" "${pushed_marker}"' EXIT
export GITHUB_OUTPUT="${github_output}"
export SOURCE_SHA=0123456789abcdef0123456789abcdef01234567
export PREFLIGHT_STATE=__PREFLIGHT_STATE__
export PREFLIGHT_DIGEST=__PREFLIGHT_DIGEST__
export PREFLIGHT_CONFIG_DIGEST=__PREFLIGHT_CONFIG_DIGEST__
export CANDIDATE_CONFIG_DIGEST=__CANDIDATE_CONFIG_DIGEST__
export INITIALLY_ABSENT=__INITIALLY_ABSENT__
export GHCR_ACTOR=ci-contract
export GHCR_TOKEN=ghs_contract

ghcr_manifest_lookup() {
  test "$1" = 'ghcr.io/devpathai/devpath-admin'
  test "$2" = "${SOURCE_SHA}"
  if test "${INITIALLY_ABSENT}" = true && ! test -f "${pushed_marker}"; then
    printf 'absent\n'
    return
  fi
  printf 'present %s\n' "${root_digest}"
}

docker() {
  case "$*" in
    "buildx imagetools inspect ghcr.io/devpathai/devpath-admin:${SOURCE_SHA} --format {{.Manifest.Digest}}")
      printf '%s\n' "${root_digest}"
      ;;
    "buildx imagetools inspect ghcr.io/devpathai/devpath-admin@${root_digest} --raw")
      jq -nc --arg digest "${remote_config}" '{
        schemaVersion: 2,
        mediaType: "application/vnd.oci.image.manifest.v1+json",
        config: {digest: $digest},
        layers: []
      }'
      ;;
    "buildx imagetools inspect ghcr.io/devpathai/devpath-admin@${root_digest} --format {{json .Image}}")
      jq -nc --arg sha "${SOURCE_SHA}" '{
        architecture: "amd64",
        os: "linux",
        config: {Labels: {
          "org.opencontainers.image.revision": $sha,
          "org.opencontainers.image.source":
            "https://github.com/DevPathAi/devpath-frontend"
        }}
      }'
      ;;
    tag*|push*)
      echo "MUTATION: docker $*" >&2
      if test "${INITIALLY_ABSENT}" = true; then
        if test "$1" = push; then
          : >"${pushed_marker}"
        fi
        return 0
      fi
      return 97
      ;;
    *)
      echo "unexpected docker invocation: $*" >&2
      return 98
      ;;
  esac
}
''' +
        publisher +
        r'''
printf '__GITHUB_OUTPUT__\n'
cat "${github_output}"
''';

    final process = await Process.start('bash', ['-s', '--', 'bind']);
    process.stdin.write(
      harness
          .replaceAll('__CANDIDATE_CONFIG_DIGEST__', candidateConfigDigest)
          .replaceAll(
            '__PREFLIGHT_STATE__',
            initiallyAbsent ? 'absent' : 'present',
          )
          .replaceAll(
            '__PREFLIGHT_DIGEST__',
            initiallyAbsent ? "''" : '"\${root_digest}"',
          )
          .replaceAll(
            '__PREFLIGHT_CONFIG_DIGEST__',
            initiallyAbsent ? "''" : '"\${remote_config}"',
          )
          .replaceAll(
            '__INITIALLY_ABSENT__',
            initiallyAbsent ? 'true' : 'false',
          ),
    );
    await process.stdin.close();
    final stdout = await process.stdout.transform(utf8.decoder).join();
    final stderr = await process.stderr.transform(utf8.decoder).join();
    final exitCode = await process.exitCode;
    return ProcessResult(process.pid, exitCode, stdout, stderr);
  }

  test('admin publication is push-main-only and immutable per source SHA', () {
    final workflow = workflowFile.readAsStringSync().replaceAll('\r\n', '\n');
    final publisher = publisherFile.readAsStringSync().replaceAll('\r\n', '\n');
    final admin = job(workflow, 'admin-image');

    expect(admin, contains("github.event_name == 'push'"));
    expect(
      admin,
      contains("github.repository == 'DevPathAi/devpath-frontend'"),
    );
    expect(admin, contains("github.ref == 'refs/heads/main'"));
    expect(admin, contains('group: admin-image-\${{ github.sha }}'));
    expect(admin, contains('cancel-in-progress: false'));
    expect(admin, contains('id: immutable-admin-tag'));
    expect(admin, contains('id: admin-candidate'));
    expect(admin, contains('load: true'));
    expect(admin, contains('push: false'));
    expect(
      publisher,
      contains("readonly IMAGE_REPOSITORY='ghcr.io/devpathai/devpath-admin'"),
    );
    expect(admin, isNot(contains('ghcr.io/devpathai/devpath-admin:main')));
    expect(
      admin,
      contains('org.opencontainers.image.revision=\${{ github.sha }}'),
    );
    expect(
      admin,
      contains(
        'org.opencontainers.image.source='
        'https://github.com/DevPathAi/devpath-frontend',
      ),
    );
    expect(admin, isNot(contains('overwrite: true')));
  });

  test('admin tag is inspected, bound once, and re-inspected as evidence', () {
    final workflow = workflowFile.readAsStringSync().replaceAll('\r\n', '\n');
    final publisher = publisherFile.readAsStringSync().replaceAll('\r\n', '\n');
    final admin = job(workflow, 'admin-image');
    final preflight = admin.indexOf('name: Inspect immutable admin tag');
    final candidate = admin.indexOf('id: admin-candidate');
    final bind = admin.indexOf('name: Bind immutable admin tag once');
    final evidence = admin.indexOf(
      'name: Record immutable admin digest evidence',
    );

    expect(preflight, greaterThanOrEqualTo(0));
    expect(candidate, greaterThan(preflight));
    expect(bind, greaterThan(candidate));
    expect(evidence, greaterThan(bind));
    expect(publisher, contains('docker push'));
    expect(publisher, contains('ghcr_manifest_lookup'));
    expect(publisher, contains('failed closed'));
    expect(publisher, contains('mission-spine.admin-artifact.v1'));
    expect(publisher, contains('actual_source_sha'));
    expect(publisher, contains('actual_source_url'));
    expect(
      'test -z "\${trailing:-}"'.allMatches(publisher).length,
      4,
      reason: 'every registry lookup has exact stdout cardinality',
    );
    expect(
      admin,
      contains(
        'actions/upload-artifact@'
        'ea165f8d65b6e75b540449e92b4886f43607fa02',
      ),
    );
    expect(
      admin,
      contains(
        'name: leva-admin-\${{ github.sha }}-registry-evidence-run-'
        '\${{ github.run_id }}-attempt-\${{ github.run_attempt }}',
      ),
    );
  });

  test(
    'registry credentials never enter argv and a missing client fails',
    () async {
      final wrapper = registryWrapperFile.readAsStringSync().replaceAll(
        '\r\n',
        '\n',
      );
      expect(wrapper, isNot(contains('curl')));
      expect(wrapper, isNot(contains('--user')));
      expect(wrapper, isNot(contains(r'${GHCR_TOKEN}')));
      expect(
        wrapper,
        contains(
          'node "\${IMMUTABLE_REGISTRY_TOOL_ROOT}/immutable_registry.mjs" lookup',
        ),
      );

      final result = await Process.run('bash', [
        '-c',
        'source ../../tools/immutable_registry.sh; '
            'PATH=/definitely/missing; '
            'GHCR_ACTOR=ci GHCR_TOKEN=ghs_contract '
            'ghcr_manifest_lookup ghcr.io/devpathai/devpath-admin '
            '0123456789abcdef0123456789abcdef01234567',
      ]);
      expect(result.exitCode, isNot(0));
      expect(result.stdout as String, isNot(contains('absent')));
    },
  );

  test('matching immutable admin image is reused without mutation', () async {
    expect(publisherFile.existsSync(), isTrue);
    final result = await runBind(
      'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    );

    expect(result.exitCode, 0, reason: result.stderr as String);
    expect(result.stdout as String, contains('mode=reused'));
    expect(result.stderr as String, isNot(contains('MUTATION:')));
  });

  test('different admin config is rejected before tag mutation', () async {
    expect(publisherFile.existsSync(), isTrue);
    final result = await runBind(
      'sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
    );

    expect(result.exitCode, isNot(0));
    expect(result.stderr as String, contains('candidate config drift'));
    expect(result.stderr as String, isNot(contains('MUTATION:')));
  });

  test('an absent admin tag is pushed once and re-inspected', () async {
    const matchingConfig =
        'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    final result = await runBind(matchingConfig, initiallyAbsent: true);

    expect(result.exitCode, 0, reason: result.stderr as String);
    expect(result.stdout as String, contains('mode=created'));
    expect(
      result.stderr as String,
      contains('MUTATION: docker tag leva-admin-candidate:'),
    );
    expect(
      result.stderr as String,
      contains('MUTATION: docker push ghcr.io/devpathai/devpath-admin:'),
    );
  });

  test('frontend CI contains no direct admin deploy or GitOps mutation', () {
    final workflow = workflowFile.readAsStringSync().replaceAll('\r\n', '\n');
    expect(
      workflow,
      contains('run: node --test tools/immutable_registry.test.mjs'),
    );
    expect(workflow, isNot(contains('\n  admin-deploy:')));
    expect(workflow, isNot(contains('GITOPS_APP_ID')));
    expect(workflow, isNot(contains('GITOPS_APP_PRIVATE_KEY')));
    expect(workflow, isNot(contains('repository: DevPathAi/devpath-gitops')));
    expect(workflow, isNot(contains('git push')));
  });
}
