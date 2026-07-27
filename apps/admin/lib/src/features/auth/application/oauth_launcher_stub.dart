import 'oauth_launcher.dart';

class _StubOAuthLauncher implements OAuthLauncher {
  const _StubOAuthLauncher();
  @override
  void launch(String url) {
    throw UnsupportedError(
      'OAuthLauncher.launch is not supported on non-web platforms. '
      'Override oauthLauncherProvider in tests with a Fake.',
    );
  }
}

OAuthLauncher createOAuthLauncher() => const _StubOAuthLauncher();
