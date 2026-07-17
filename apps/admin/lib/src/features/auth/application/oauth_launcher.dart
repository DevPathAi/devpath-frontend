import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'oauth_launcher_web.dart'
    if (dart.library.io) 'oauth_launcher_stub.dart';

abstract interface class OAuthLauncher {
  void launch(String url);
}

final oauthLauncherProvider = Provider<OAuthLauncher>(
  (ref) => createOAuthLauncher(),
);
