import 'oauth_launcher.dart';

/// VM/테스트 스텁. 실제 리다이렉트는 불가 — 테스트에서 oauthLauncherProvider를 override해 사용.
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

/// 조건부 임포트에서 호출하는 팩토리 함수.
OAuthLauncher createOAuthLauncher() => const _StubOAuthLauncher();
