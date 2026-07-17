import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/api_providers.dart';
import '../state/auth_state.dart';
import 'oauth_launcher.dart';

class AdminAuthController extends Notifier<AdminAuthState> {
  @override
  AdminAuthState build() => const AdminUnauthed();

  Future<void> login({String provider = 'github'}) async {
    final base = ref.read(appConfigProvider).baseUrl;
    ref
        .read(oauthLauncherProvider)
        .launch('$base/oauth2/authorization/$provider?client_type=admin');
  }

  Future<void> logout() async {
    await ref.read(tokenStoreProvider).clear();
    state = const AdminUnauthed();
  }
}

final adminAuthProvider = NotifierProvider<AdminAuthController, AdminAuthState>(
  AdminAuthController.new,
);
