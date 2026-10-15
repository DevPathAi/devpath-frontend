import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 점검 A-4(2026-10-11): app.leva.ai.kr 응답에 HSTS·X-Frame-Options 등이 없고
/// `Server: nginx/1.31.3` 으로 버전이 드러났다. 로그인 화면이 다른 사이트 프레임에
/// 들어갈 수 있었다.
///
/// nginx 는 `location` 에 `add_header` 가 하나라도 있으면 `server` 의 `add_header`
/// 를 상속하지 않는다. 그래서 앱 화면을 내려보내는 `location /` 안에 직접 둔다.
/// CSP 는 Flutter Web(인라인 부트스트랩·wasm)·애드센스 출처 실측과 위반 보고 수집처가
/// 먼저라 이 계약에 넣지 않는다.
void main() {
  final nginx = File('nginx.conf').readAsStringSync().replaceAll('\r\n', '\n');

  String block(String opener) {
    final start = nginx.indexOf(opener);
    expect(start, greaterThanOrEqualTo(0), reason: '$opener 블록 없음');
    var depth = 0;
    for (var i = nginx.indexOf('{', start); i < nginx.length; i++) {
      if (nginx[i] == '{') depth++;
      if (nginx[i] == '}' && --depth == 0) return nginx.substring(start, i + 1);
    }
    fail('$opener 블록이 닫히지 않음');
  }

  test('server 블록이 nginx 버전을 숨긴다', () {
    expect(block('server {'), contains('server_tokens off;'));
  });

  test('앱 화면 응답(location /)이 보안 헤더를 항상 붙인다', () {
    final root = block('location / {');
    for (final header in const [
      'add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;',
      'add_header X-Content-Type-Options "nosniff" always;',
      'add_header X-Frame-Options "DENY" always;',
      'add_header Referrer-Policy "strict-origin-when-cross-origin" always;',
      'add_header Permissions-Policy "geolocation=(), microphone=(), camera=()" always;',
    ]) {
      expect(root, contains(header), reason: header);
    }
    // 기존 재검증 캐시 정책은 그대로다(add_header 를 더해도 사라지면 안 된다).
    expect(root, contains('add_header Cache-Control "no-cache" always;'));
  });
}
