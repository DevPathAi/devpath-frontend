import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/api_providers.dart';
import '../state/auth_state.dart';

/// 목 OAuth 로그인/로그아웃. 프로토는 메모리 토큰이라 시작 시 항상 미인증.
class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthUnauthenticated();

  ApiClient get _client => ref.read(apiClientProvider);
  TokenStore get _store => ref.read(tokenStoreProvider);

  Future<void> login() async {
    try {
      final data = await _client.post<Map<String, dynamic>>('/auth/login');
      await _store.save(
        access: data['accessToken'] as String,
        refresh: data['refreshToken'] as String,
      );
      state = AuthAuthenticated(
        User.fromJson((data['user'] as Map).cast<String, dynamic>()),
      );
    } on ApiException catch (e) {
      state = AuthUnauthenticated(error: e.message);
    }
  }

  Future<void> logout() async {
    await _store.clear();
    state = const AuthUnauthenticated();
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
