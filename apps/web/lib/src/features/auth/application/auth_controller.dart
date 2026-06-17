import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/api_providers.dart';
import '../state/auth_state.dart';
import 'oauth_launcher.dart';

/// OAuth 로그인/로그아웃. login()은 OAuth 리다이렉트, bootstrapFromCallback()은
/// OAuth 콜백 후 세션 복원, bootstrapSession()은 앱 시작 시 자동 세션 복원.
class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    // 앱 시작 1회 세션 복원 시도. AuthLoading 반환 후 microtask로 비동기 실행하여
    // build() 완료(동기) → 상태 갱신(비동기) 순서를 보장한다.
    // ref.onDispose로 dispose 후 microtask 진입을 차단한다.
    var disposed = false;
    ref.onDispose(() => disposed = true);
    Future.microtask(() {
      if (!disposed) bootstrapSession();
    });
    return const AuthLoading();
  }

  ApiClient get _client => ref.read(apiClientProvider);
  TokenStore get _store => ref.read(tokenStoreProvider);

  /// GitHub OAuth 흐름 시작: 브라우저를 gateway OAuth 엔드포인트로 리다이렉트.
  /// 실제 리다이렉트는 [oauthLauncherProvider]에 위임(테스트에서 Fake로 교체 가능).
  Future<void> login() async {
    final base = ref.read(appConfigProvider).baseUrl;
    ref.read(oauthLauncherProvider).launch('$base/oauth2/authorization/github');
  }

  /// 앱 시작 세션 복원: POST /auth/refresh(HttpOnly 쿠키, 본문 없음) → access 저장
  /// + User 파싱 → AuthAuthenticated. 쿠키 없음/만료(401) → AuthUnauthenticated.
  /// build()에서 Future.microtask로 자동 호출된다(앱 시작 1회).
  /// 인증된 유저(AuthAuthenticated)가 이미 있으면 재실행하지 않는다.
  Future<void> bootstrapSession() async {
    // 이미 인증 완료된 상태면 재실행 방지(예: bootstrapFromCallback 이후 재진입).
    if (state is AuthAuthenticated) return;
    try {
      final data = await _client.post<Map<String, dynamic>>('/auth/refresh');
      if (!ref.mounted) return; // dispose 후 async gap에서 진입 방지
      await _store.save(access: data['access_token'] as String, refresh: '');
      if (!ref.mounted) return;
      state = AuthAuthenticated(
        User.fromJson((data['user'] as Map).cast<String, dynamic>()),
      );
    } on ApiException {
      if (!ref.mounted) return;
      state = const AuthUnauthenticated(); // 쿠키 없음/만료 → 미인증
    }
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
