import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/api_providers.dart';
import '../state/auth_state.dart';

class AdminAuthController extends Notifier<AdminAuthState> {
  @override
  AdminAuthState build() => const AdminUnauthed();

  Future<void> login() async {
    try {
      final data = await ref
          .read(apiClientProvider)
          .post<Map<String, dynamic>>('/admin/auth/login');
      await ref.read(tokenStoreProvider).save(
            access: data['accessToken'] as String,
            refresh: data['refreshToken'] as String,
          );
      state = AdminAuthed(
          User.fromJson((data['user'] as Map).cast<String, dynamic>()));
    } on ApiException catch (e) {
      state = AdminUnauthed(error: e.message);
    }
  }

  Future<void> logout() async {
    await ref.read(tokenStoreProvider).clear();
    state = const AdminUnauthed();
  }
}

final adminAuthProvider =
    NotifierProvider<AdminAuthController, AdminAuthState>(AdminAuthController.new);
