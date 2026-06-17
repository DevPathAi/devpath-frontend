import 'package:web/web.dart' as web;

import 'oauth_launcher.dart';

/// 웹 프로덕션 구현: window.location.href로 브라우저 리다이렉트.
class _WebOAuthLauncher implements OAuthLauncher {
  const _WebOAuthLauncher();

  @override
  void launch(String url) {
    web.window.location.href = url;
  }
}

/// 조건부 임포트에서 호출하는 팩토리 함수.
OAuthLauncher createOAuthLauncher() => const _WebOAuthLauncher();
