import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/api_providers.dart';
import '../state/auth_state.dart';
import 'oauth_launcher.dart';

/// OAuth 로그인/로그아웃. login()은 OAuth 리다이렉트, bootstrapFromCallback()은
/// /auth/refresh 쿠키 기반 세션 복원.
class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthUnauthenticated();

  ApiClient get _client => ref.read(apiClientProvider);
  TokenStore get _store => ref.read(tokenStoreProvider);

  /// GitHub OAuth 흐름 시작: 브라우저를 gateway OAuth 엔드포인트로 리다이렉트.
  /// 실제 리다이렉트는 [oauthLauncherProvider]에 위임(테스트에서 Fake로 교체 가능).
  Future<void> login() async {
    final base = ref.read(appConfigProvider).baseUrl;
    ref.read(oauthLauncherProvider).launch('$base/oauth2/authorization/github');
  }

  /// OAuth 콜백 후 세션 복원: POST /auth/refresh(쿠키, 본문 없음) → access 저장
  /// + User 파싱 → AuthAuthenticated. 실패 시 AuthUnauthenticated(error).
  Future<void> bootstrapFromCallback() async {
    try {
      final data = await _client.post<Map<String, dynamic>>('/auth/refresh');
      await _store.save(access: data['access_token'] as String, refresh: '');
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

  /// 온보딩 완료로 갱신된 유저 반영(게이트 재평가 트리거).
  void onboardingCompleted(User user) {
    if (state is AuthAuthenticated) state = AuthAuthenticated(user);
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
