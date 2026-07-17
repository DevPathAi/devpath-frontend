import 'package:dp_core/dp_core.dart';
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

  /// OAuth 콜백 후 세션 복원: POST /auth/refresh(쿠키, 본문 없음) → access 저장
  /// + User 파싱 → AdminAuthed. 실패 시 AdminUnauthed(error).
  Future<void> bootstrapFromCallback() async {
    try {
      final data = await ref.read(apiClientProvider)
          .post<Map<String, dynamic>>('/auth/refresh');
      await ref.read(tokenStoreProvider)
          .save(access: data['access_token'] as String, refresh: '');
      state = AdminAuthed(
        User.fromJson((data['user'] as Map).cast<String, dynamic>()));
    } on ApiException catch (e) {
      state = AdminUnauthed(error: e.message);
    } catch (_) {
      state = const AdminUnauthed();
    }
  }

  Future<void> logout() async {
    await ref.read(tokenStoreProvider).clear();
    state = const AdminUnauthed();
  }
}

final adminAuthProvider = NotifierProvider<AdminAuthController, AdminAuthState>(
  AdminAuthController.new,
);
