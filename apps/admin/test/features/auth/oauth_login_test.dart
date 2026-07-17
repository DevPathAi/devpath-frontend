import 'package:devpath_admin/src/features/auth/application/auth_controller.dart';
import 'package:devpath_admin/src/features/auth/application/oauth_launcher.dart';
import 'package:devpath_admin/src/providers/api_providers.dart';
import 'package:devpath_admin/src/app/app_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeLauncher implements OAuthLauncher {
  String? launched;
  @override
  void launch(String url) => launched = url;
}

void main() {
  test('login() launches OAuth with client_type=admin', () async {
    final fake = _FakeLauncher();
    final container = ProviderContainer(
      overrides: [
        oauthLauncherProvider.overrideWithValue(fake),
        appConfigProvider.overrideWithValue(
          const AppConfig(baseUrl: 'https://api.test', useMock: false),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(adminAuthProvider.notifier).login();

    expect(
      fake.launched,
      'https://api.test/oauth2/authorization/github?client_type=admin',
    );
  });
}
