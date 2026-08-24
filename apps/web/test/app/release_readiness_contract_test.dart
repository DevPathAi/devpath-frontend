import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('web runtime exposes only an authenticated sealed release identity', () {
    final dockerfile = File('Dockerfile').readAsStringSync();
    final nginx = File('nginx.conf').readAsStringSync();
    final entrypoint = File(
      'release-entrypoint.sh',
    ).readAsStringSync().replaceAll('\r\n', '\n');
    final workflow = File('../../.github/workflows/ci.yml').readAsStringSync();
    final smoke = File(
      '../../tools/web_release_readiness_smoke.sh',
    ).readAsStringSync().replaceAll('\r\n', '\n');

    expect(
      dockerfile,
      contains(
        'COPY apps/web/nginx.conf /etc/nginx/templates/default.conf.template',
      ),
    );
    expect(
      dockerfile,
      contains('ENTRYPOINT ["/usr/local/bin/devpath-release-entrypoint"]'),
    );
    expect(dockerfile, contains('NGINX_ENVSUBST_FILTER="^MISSION_"'));

    expect(nginx, contains('map_hash_bucket_size 128;'));
    expect(nginx, contains('location = /internal/release/ready'));
    expect(nginx, contains('"Bearer \${MISSION_SYNTHETIC_PROBE_TOKEN}" 1;'));
    expect(nginx, contains('if (\$mission_release_ready != "true")'));
    expect(nginx, contains('if (\$mission_probe_authorized = 0)'));
    expect(nginx, contains('add_header Cache-Control "no-store" always;'));
    expect(
      nginx,
      contains(
        '{"release_id":"\$mission_release_id",'
        '"candidate_spec_sha256":"\$mission_candidate_spec_sha256",'
        '"image_digest":"\$mission_image_digest","status":"ready"}',
      ),
    );

    expect(entrypoint, contains("case \"\${MISSION_RELEASE_READY:-}\" in"));
    expect(entrypoint, contains("*'\n'*) return 1 ;;"));
    expect(entrypoint, contains("'^ms-[0-9]{8}-[a-z0-9][a-z0-9-]{2,40}\$'"));
    expect(entrypoint, contains("'^[0-9a-f]{64}\$'"));
    expect(entrypoint, contains("'^sha256:[0-9a-f]{64}\$'"));
    expect(entrypoint, contains("exec /docker-entrypoint.sh \"\$@\""));

    expect(workflow, contains('Smoke authenticated release readiness'));
    expect(workflow, contains('type=docker'));
    expect(
      RegExp(
        r'bash tools/web_release_readiness_smoke\.sh',
      ).allMatches(workflow).length,
      2,
    );

    expect(smoke, contains('--env MISSION_RELEASE_READY=true'));
    expect(smoke, contains("--write-out '%{http_code}'"));
    expect(smoke, contains('assert_status disabled_unauth_status 401'));
    expect(smoke, contains('assert_status disabled_auth_status 503'));
    expect(smoke, contains('assert_status ready_unauth_status 401'));
    expect(smoke, contains('assert_status ready_auth_status 200'));
    expect(smoke, contains('Authorization: Bearer \${PROBE_TOKEN}'));
    expect(smoke, contains("tr -d '\\r'"));
    expect(smoke, contains('Cache-Control: no-store'));
    expect(smoke, contains('X-Content-Type-Options: nosniff'));
    expect(
      smoke,
      contains(
        'disabled_container="mission-readiness-\${GITHUB_RUN_ID}-'
        '\${identity}-disabled"',
      ),
    );
    expect(
      smoke,
      contains(
        'ready_container="mission-readiness-\${GITHUB_RUN_ID}-'
        '\${identity}-ready"',
      ),
    );
    expect(smoke, contains('disabled_port=18080'));
    expect(smoke, contains('ready_port=18081'));
    expect(
      smoke,
      contains('wait_for_web "\${disabled_container}" "\${disabled_port}"'),
    );
    expect(
      smoke,
      contains('wait_for_web "\${ready_container}" "\${ready_port}"'),
    );
  });
}
