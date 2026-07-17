import 'package:web/web.dart' as web;

import 'oauth_launcher.dart';

class _WebOAuthLauncher implements OAuthLauncher {
  const _WebOAuthLauncher();
  @override
  void launch(String url) {
    web.window.location.href = url;
  }
}

OAuthLauncher createOAuthLauncher() => const _WebOAuthLauncher();
