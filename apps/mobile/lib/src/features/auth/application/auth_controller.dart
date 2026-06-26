import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/api_providers.dart';
import '../state/auth_state.dart';
import 'oauth_launcher.dart';

/// 모바일 인증 컨트롤러.
///
/// 세션 복원은 **토큰 기반**(secure_storage): 부팅 시 저장된 access 토큰이 있으면
/// `GET /users/me`로 사용자를 복원한다(웹은 쿠키 기반 /auth/refresh — 전송 방식만 다름).
///
/// OAuth: 실모드 [login]은 인가 URL을 외부 브라우저로 연다. 콜백은 딥링크
/// `devpath://callback`로 토큰을 싣고 돌아오며 [completeFromDeepLink]가 처리한다.
/// 목 모드는 [mockLogin]이 가짜 토큰을 저장하고 /users/me 목 픽스처로 세션을 구성한다.
class AuthController extends Notifier<AuthState> {
  ApiClient get _client => ref.read(apiClientProvider);
  TokenStore get _store => ref.read(tokenStoreProvider);

  @override
  AuthState build() {
    var disposed = false;
    ref.onDispose(() => disposed = true);
    Future.microtask(() {
      if (!disposed) bootstrapSession();
    });
    return const AuthLoading();
  }

  /// 실모드 OAuth 시작 — GitHub 인가 엔드포인트를 외부 브라우저로 연다.
  Future<void> login() async {
    final base = ref.read(appConfigProvider).baseUrl;
    await ref
        .read(oauthLauncherProvider)
        .launch('$base/oauth2/authorization/github');
  }

  /// 목 모드 로그인 — 딥링크 도착을 가짜 토큰으로 대체해 동일 경로로 세션 구성.
  Future<void> mockLogin() => completeFromDeepLink(
    const TokenPair(access: 'mock-access', refresh: 'mock-refresh'),
  );

  /// 부팅 세션 복원 — 저장된 access 토큰이 있으면 /users/me 로 사용자 조회.
  Future<void> bootstrapSession() async {
    final access = await _store.readAccess();
    if (access == null || access.isEmpty) {
      if (!ref.mounted) return;
      state = const AuthUnauthenticated();
      return;
    }
    try {
      final json = await _client.get<Map<String, dynamic>>('/users/me');
      if (!ref.mounted) return;
      state = AuthAuthenticated(User.fromJson(json));
    } on ApiException catch (e) {
      if (!ref.mounted) return;
      state = AuthUnauthenticated(error: e.message);
    }
  }

  /// 딥링크 콜백 토큰 수신 — secure_storage 저장 후 세션 복원.
  Future<void> completeFromDeepLink(TokenPair tokens) async {
    await _store.save(access: tokens.access, refresh: tokens.refresh);
    if (!ref.mounted) return;
    await bootstrapSession();
  }

  Future<void> logout() async {
    await _store.clear();
    if (!ref.mounted) return;
    state = const AuthUnauthenticated();
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
