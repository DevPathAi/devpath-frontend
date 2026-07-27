import 'package:devpath_admin/src/app/app_config.dart';
import 'package:devpath_admin/src/features/auth/application/auth_controller.dart';
import 'package:devpath_admin/src/features/auth/application/oauth_launcher.dart';
import 'package:devpath_admin/src/providers/api_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeLauncher implements OAuthLauncher {
  String? launched;
  @override
  void launch(String url) => launched = url;
}

void main() {
  test('login() OAuth 런처를 호출하고 client_type=admin URL을 전달', () async {
    final fake = _FakeLauncher();
    final c = ProviderContainer(
      overrides: [
        oauthLauncherProvider.overrideWithValue(fake),
        appConfigProvider.overrideWithValue(
          const AppConfig(baseUrl: 'https://api.test', useMock: false),
        ),
      ],
    );
    addTearDown(c.dispose);

    await c.read(adminAuthProvider.notifier).login();

    expect(
      fake.launched,
      'https://api.test/oauth2/authorization/github?client_type=admin',
    );
  });

  test('login(provider: google) Google OAuth URL을 전달', () async {
    final fake = _FakeLauncher();
    final c = ProviderContainer(
      overrides: [
        oauthLauncherProvider.overrideWithValue(fake),
        appConfigProvider.overrideWithValue(
          const AppConfig(baseUrl: 'https://api.test', useMock: false),
        ),
      ],
    );
    addTearDown(c.dispose);

    await c.read(adminAuthProvider.notifier).login(provider: 'google');

    expect(
      fake.launched,
      'https://api.test/oauth2/authorization/google?client_type=admin',
    );
  });
}
