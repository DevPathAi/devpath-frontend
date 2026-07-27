import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/api_providers.dart';
import '../state/auth_state.dart';
import 'oauth_launcher.dart';
import 'pkce.dart';

/// 모바일 인증 컨트롤러.
///
/// 세션 복원은 **토큰 기반**(secure_storage): 부팅 시 저장된 access 토큰이 있으면
/// `GET /users/me`로 사용자를 복원한다(웹은 쿠키 기반 /auth/refresh — 전송 방식만 다름).
///
/// OAuth(하드닝 트랙 A — 일회용 code + PKCE): 실모드 [login]은 PKCE verifier를 만들어
/// 보관하고 인가 URL을 외부 브라우저로 연다. 콜백은 딥링크 `devpath://callback?code=`로
/// **토큰이 아닌 일회용 code**를 싣고 돌아오며 [completeFromCode]가 verifier와 함께
/// `/auth/oauth/token`으로 교환한다(토큰은 URL에 실리지 않는다).
/// 목 모드는 [mockLogin]이 가짜 토큰을 저장하고 /users/me 목 픽스처로 세션을 구성한다.
class AuthController extends Notifier<AuthState> {
  ApiClient get _client => ref.read(apiClientProvider);
  TokenStore get _store => ref.read(tokenStoreProvider);

  /// PKCE verifier 임시 보관 키(콜백이 새 프로세스로 와도 복원되도록 영속 저장).
  static const _kPkceVerifier = 'dp.auth.pkce_verifier';

  @override
  AuthState build() {
    var disposed = false;
    ref.onDispose(() => disposed = true);
    Future.microtask(() {
      if (!disposed) bootstrapSession();
    });
    return const AuthLoading();
  }

  /// 실모드 OAuth 시작 — PKCE verifier를 생성·보관하고 인가 URL을 외부 브라우저로 연다.
  ///
  /// `client_type=mobile` + `code_challenge`(S256)로 모바일 PKCE 플로우임을 알린다 →
  /// 백엔드가 성공 후 `devpath://callback?code=`(일회용 code) 딥링크로 회신한다(웹은 쿠키).
  Future<void> login() async {
    final pkce = PkcePair.generate();
    await ref.read(keyValueStoreProvider).write(_kPkceVerifier, pkce.verifier);
    final base = ref.read(appConfigProvider).baseUrl;
    await ref
        .read(oauthLauncherProvider)
        .launch(
          '$base/oauth2/authorization/github'
          '?client_type=mobile'
          '&code_challenge=${pkce.challenge}'
          '&code_challenge_method=S256',
        );
  }

  /// 목 모드 로그인 — 코드 교환을 생략하고 가짜 토큰을 저장해 동일 경로로 세션 구성.
  Future<void> mockLogin() async {
    await _store.save(access: 'mock-access', refresh: 'mock-refresh');
    if (!ref.mounted) return;
    await bootstrapSession();
  }

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

  /// 딥링크 콜백 code 수신 — 보관한 PKCE verifier와 함께 `/auth/oauth/token`으로 교환,
  /// 토큰 저장 후 세션 복원. verifier가 없거나(만료/유실) 교환 실패 시 미인증으로 둔다.
  Future<void> completeFromCode(String code) async {
    final kv = ref.read(keyValueStoreProvider);
    final verifier = await kv.read(_kPkceVerifier);
    if (verifier == null || verifier.isEmpty) {
      if (!ref.mounted) return;
      state = const AuthUnauthenticated(error: 'PKCE verifier 없음(로그인 재시도 필요)');
      return;
    }
    try {
      final data = await _client.post<Map<String, dynamic>>(
        '/auth/oauth/token',
        body: {'code': code, 'code_verifier': verifier},
      );
      await _store.save(
        access: data['access_token'] as String,
        refresh: data['refresh_token'] as String,
      );
      if (!ref.mounted) return;
      await bootstrapSession();
    } on ApiException catch (e) {
      if (!ref.mounted) return;
      state = AuthUnauthenticated(error: e.message);
    } finally {
      // 1회용 PKCE verifier: code는 교환을 시도한 순간 서버에서 소비되므로
      // 성공/실패와 무관하게 폐기한다(secure_storage에 만료된 비밀 잔존 방지).
      await kv.delete(_kPkceVerifier);
    }
  }

  Future<void> logout() async {
    await _store.clear();
    if (!ref.mounted) return;
    state = const AuthUnauthenticated();
  }

  /// 온보딩 완료 — 갱신된 사용자로 세션 상태를 교체한다(게이트가 진입점으로 통과).
  void onboardingCompleted(User user) {
    if (state is AuthAuthenticated) state = AuthAuthenticated(user);
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
