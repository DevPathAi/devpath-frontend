import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/api_providers.dart';
import '../../../data/account_data_cleaner.dart';
import '../state/auth_state.dart';
import 'oauth_launcher.dart';
import 'pending_deep_link_controller.dart';
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
  Future<void>? _bootstrapInFlight;
  Future<void> _credentialMutationTail = Future<void>.value();
  var _epoch = 0;

  @override
  AuthState build() {
    ref.onDispose(() {
      _epoch += 1;
      _bootstrapInFlight = null;
    });
    Future.microtask(() {
      if (ref.mounted) bootstrapSession();
    });
    return const AuthLoading();
  }

  /// 실모드 OAuth 시작 — PKCE verifier를 생성·보관하고 인가 URL을 외부 브라우저로 연다.
  ///
  /// `client_type=mobile` + `code_challenge`(S256)로 모바일 PKCE 플로우임을 알린다 →
  /// 백엔드가 성공 후 `devpath://callback?code=`(일회용 code) 딥링크로 회신한다(웹은 쿠키).
  Future<void> login() async {
    final pkce = PkcePair.generate();
    await _mutateCredentials(
      () =>
          ref.read(keyValueStoreProvider).write(_kPkceVerifier, pkce.verifier),
    );
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
    final epoch = ++_epoch;
    _bootstrapInFlight = null;
    final saved = await _mutateCredentials(() async {
      if (!_isCurrent(epoch)) return false;
      await _store.save(access: 'mock-access', refresh: 'mock-refresh');
      return _isCurrent(epoch);
    });
    if (!saved) return;
    await bootstrapSession();
  }

  /// 부팅 세션 복원 — 저장된 access 토큰이 있으면 /users/me 로 사용자 조회.
  Future<void> bootstrapSession() {
    final active = _bootstrapInFlight;
    if (active != null) return active;
    final epoch = _epoch;
    late final Future<void> tracked;
    tracked = _bootstrap(epoch).whenComplete(() {
      if (identical(_bootstrapInFlight, tracked)) _bootstrapInFlight = null;
    });
    _bootstrapInFlight = tracked;
    return tracked;
  }

  Future<void> _bootstrap(int epoch) async {
    final access = await _store.readAccess();
    if (!_isCurrent(epoch)) return;
    if (access == null || access.isEmpty) {
      state = const AuthUnauthenticated();
      return;
    }
    try {
      final json = await _client.get<Map<String, dynamic>>('/users/me');
      if (!_isCurrent(epoch)) return;
      state = AuthAuthenticated(User.fromJson(json));
    } on ApiException catch (e) {
      if (!_isCurrent(epoch)) return;
      if (e.status == 401 || e.code == ApiErrorCode.unauthorized) {
        final cleared = await _mutateCredentials(() async {
          if (!_isCurrent(epoch)) return false;
          await _store.clear();
          return _isCurrent(epoch);
        });
        if (!cleared) return;
        state = AuthUnauthenticated(error: e.message);
      } else {
        state = AuthSessionUnavailable(e.message);
      }
    }
  }

  Future<void> retrySession() async {
    _epoch += 1;
    _bootstrapInFlight = null;
    state = const AuthLoading();
    await bootstrapSession();
  }

  /// 딥링크 콜백 code 수신 — 보관한 PKCE verifier와 함께 `/auth/oauth/token`으로 교환,
  /// 토큰 저장 후 세션 복원. verifier가 없거나(만료/유실) 교환 실패 시 미인증으로 둔다.
  Future<void> completeFromCode(String code) async {
    final epoch = ++_epoch;
    _bootstrapInFlight = null;
    final kv = ref.read(keyValueStoreProvider);
    final verifier = await kv.read(_kPkceVerifier);
    if (verifier == null || verifier.isEmpty) {
      if (!_isCurrent(epoch)) return;
      state = const AuthUnauthenticated(error: 'PKCE verifier 없음(로그인 재시도 필요)');
      return;
    }
    try {
      final data = await _client.post<Map<String, dynamic>>(
        '/auth/oauth/token',
        body: {'code': code, 'code_verifier': verifier},
      );
      if (!_isCurrent(epoch)) return;
      final access = data['access_token'] as String;
      final refresh = data['refresh_token'] as String;
      final saved = await _mutateCredentials(() async {
        if (!_isCurrent(epoch)) return false;
        await _store.save(access: access, refresh: refresh);
        return _isCurrent(epoch);
      });
      if (!saved) return;
      await bootstrapSession();
    } on ApiException catch (e) {
      if (!_isCurrent(epoch)) return;
      state = AuthUnauthenticated(error: e.message);
    } finally {
      // 1회용 PKCE verifier: code는 교환을 시도한 순간 서버에서 소비되므로
      // 성공/실패와 무관하게 폐기한다(secure_storage에 만료된 비밀 잔존 방지).
      await _mutateCredentials(() async {
        if (await kv.read(_kPkceVerifier) == verifier) {
          await kv.delete(_kPkceVerifier);
        }
      });
    }
  }

  Future<void> logout() async {
    final ownerKey = switch (state) {
      AuthAuthenticated(:final user) => user.id,
      _ => null,
    };
    final epoch = ++_epoch;
    _bootstrapInFlight = null;
    try {
      await _mutateCredentials(() async {
        try {
          if (ownerKey != null) {
            await ref.read(accountDataCleanerProvider).clearOwner(ownerKey);
          }
        } finally {
          await _store.clear();
          await ref.read(keyValueStoreProvider).delete(_kPkceVerifier);
          await ref
              .read(keyValueStoreProvider)
              .delete(PendingDeepLinkController.storageKey);
        }
      });
    } finally {
      if (_isCurrent(epoch)) {
        ref.read(pendingDeepLinkProvider.notifier).consume();
        state = const AuthUnauthenticated();
      }
    }
  }

  bool _isCurrent(int epoch) => ref.mounted && epoch == _epoch;

  Future<T> _mutateCredentials<T>(Future<T> Function() mutation) {
    final operation = _credentialMutationTail.then((_) => mutation());
    _credentialMutationTail = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
