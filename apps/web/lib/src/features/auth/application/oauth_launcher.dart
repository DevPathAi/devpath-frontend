import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'oauth_launcher_web.dart'
    if (dart.library.io) 'oauth_launcher_stub.dart';

/// OAuth 리다이렉트 추상화. 테스트에서 Fake로 교체 가능.
abstract interface class OAuthLauncher {
  void launch(String url);
}

/// Provider. 웹 런타임은 WebOAuthLauncher, 테스트는 override.
final oauthLauncherProvider = Provider<OAuthLauncher>(
  (ref) => createOAuthLauncher(),
);
