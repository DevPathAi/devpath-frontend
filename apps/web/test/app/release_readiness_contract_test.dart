import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('web runtime exposes only an authenticated sealed release identity', () {
    final dockerfile = File('Dockerfile').readAsStringSync();
    final nginx = File('nginx.conf').readAsStringSync();
    final entrypoint = File('release-entrypoint.sh').readAsStringSync();
    final workflow = File('../../.github/workflows/ci.yml').readAsStringSync();

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
    expect(workflow, contains('--env MISSION_RELEASE_READY=true'));
    expect(workflow, contains("--write-out '%{http_code}'"));
    expect(workflow, contains("= \"401\""));
    expect(workflow, contains("= \"503\""));
    expect(workflow, contains('Authorization: Bearer \${PROBE_TOKEN}'));
    expect(workflow, contains('^Cache-Control: no-store\\r?\$'));
  });
}
