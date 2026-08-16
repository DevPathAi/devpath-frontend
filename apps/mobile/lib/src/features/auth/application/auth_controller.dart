import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/api_providers.dart';
import '../../../data/account_data_cleaner.dart';
import '../../notifications/application/device_registrar.dart';
import '../state/auth_state.dart';
import 'oauth_launcher.dart';
import 'account_epoch_store.dart';
import 'credential_mutation_coordinator.dart';
import 'pending_deep_link_controller.dart';
import 'pkce.dart';
import 'verified_session_store.dart';

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
  ApiClient get _authFlowClient => ref.read(authFlowClientProvider);
  TokenStore get _store => ref.read(tokenStoreProvider);

  /// PKCE verifier 임시 보관 키(콜백이 새 프로세스로 와도 복원되도록 영속 저장).
  static const _kPkceVerifier = 'dp.auth.pkce_verifier';
  static const _maxOAuthCodesPerFlow = 16;
  Future<void>? _bootstrapInFlight;
  Future<void> _oauthCompletionTail = Future<void>.value();
  final Map<String, Future<void>> _oauthCompletions = {};
  var _oauthFlowGeneration = 0;
  var _epoch = 0;

  @override
  AuthState build() {
    ref.onDispose(() {
      _epoch += 1;
      _oauthFlowGeneration += 1;
      _bootstrapInFlight = null;
      _resetOAuthCallbackQueue();
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
    final flowGeneration = ++_oauthFlowGeneration;
    final epoch = ++_epoch;
    _bootstrapInFlight = null;
    // Previous Futures cannot be cancelled, but their captured flow generation
    // is now stale. A new flow owns an independent bounded callback queue.
    _resetOAuthCallbackQueue();
    final pkce = PkcePair.generate();
    final stored = await _mutateCredentials(() async {
      if (!_isOAuthFlowCurrent(flowGeneration, epoch)) return false;
      await ref
          .read(keyValueStoreProvider)
          .write(_kPkceVerifier, pkce.verifier);
      return _isOAuthFlowCurrent(flowGeneration, epoch);
    });
    if (!stored || !_isOAuthFlowCurrent(flowGeneration, epoch)) return;
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
    _invalidateCredentialBoundary();
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
      final staleSession = await ref.read(verifiedSessionStoreProvider).read();
      if (staleSession != null) {
        _invalidateCredentialBoundary();
        await _revokePush(staleSession.id);
        if (!_isCurrent(epoch)) return;
        final cleared = await _mutateCredentials(() async {
          if (!_isCurrent(epoch)) return false;
          await _clearVerifiedLocalBoundary(staleSession.id);
          return _isCurrent(epoch);
        });
        if (!cleared) return;
      }
      if (!_isCurrent(epoch)) return;
      state = const AuthUnauthenticated();
      return;
    }
    final previousUser = await ref.read(verifiedSessionStoreProvider).read();
    if (!_isCurrent(epoch)) return;
    try {
      final json = await _client.get<Map<String, dynamic>>('/users/me');
      if (!_isCurrent(epoch)) return;
      final user = User.fromJson(json);
      var switchRevocationFailed = false;
      if (previousUser != null && previousUser.id != user.id) {
        _invalidateCredentialBoundary();
        switchRevocationFailed = !await _revokePush(previousUser.id);
        if (!_isCurrent(epoch)) return;
      }
      final saved = await _mutateCredentials(() async {
        if (!_isCurrent(epoch)) return false;
        if (previousUser != null && previousUser.id != user.id) {
          try {
            await ref.read(accountEpochStoreProvider).advance();
            await ref
                .read(accountDataCleanerProvider)
                .clearOwner(previousUser.id);
          } finally {
            if (switchRevocationFailed) {
              await _store.clear();
              await ref.read(verifiedSessionStoreProvider).clear();
              await ref.read(pendingDeepLinkProvider.notifier).clearPersisted();
            }
          }
          if (switchRevocationFailed) return _isCurrent(epoch);
          await ref.read(pendingDeepLinkProvider.notifier).consumeAndWait();
        }
        if (!_isCurrent(epoch)) return false;
        await ref.read(verifiedSessionStoreProvider).write(user);
        return _isCurrent(epoch);
      });
      if (!saved) return;
      if (switchRevocationFailed) {
        ref.read(pendingDeepLinkProvider.notifier).consume();
        state = const AuthUnauthenticated(
          error: '이전 계정의 알림 연결을 해제하지 못했어요. 다시 로그인해 주세요.',
        );
        return;
      }
      state = AuthAuthenticated(user);
    } on ApiException catch (e) {
      if (!_isCurrent(epoch)) return;
      if (e.status == 401 || e.code == ApiErrorCode.unauthorized) {
        _invalidateCredentialBoundary();
        await _revokePush(previousUser?.id);
        if (!_isCurrent(epoch)) return;
        final cleared = await _mutateCredentials(() async {
          if (!_isCurrent(epoch)) return false;
          await _clearVerifiedLocalBoundary(previousUser?.id);
          return _isCurrent(epoch);
        });
        if (!cleared) return;
        state = AuthUnauthenticated(error: e.message);
      } else if (previousUser != null) {
        state = AuthOfflineAuthenticated(previousUser, e.message);
      } else {
        state = AuthSessionUnavailable(e.message);
      }
    } on Object {
      if (!_isCurrent(epoch)) return;
      _invalidateCredentialBoundary();
      await _revokePush(previousUser?.id);
      if (!_isCurrent(epoch)) return;
      final cleared = await _mutateCredentials(() async {
        if (!_isCurrent(epoch)) return false;
        await _clearVerifiedLocalBoundary(previousUser?.id);
        return _isCurrent(epoch);
      });
      if (!cleared) return;
      state = const AuthUnauthenticated(
        error: '세션 응답 형식을 확인하지 못했어요. 다시 로그인해 주세요.',
      );
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
  Future<void> completeFromCode(String code) {
    final existing = _oauthCompletions[code];
    if (existing != null) return existing;
    if (_oauthCompletions.length >= _maxOAuthCodesPerFlow) {
      return Future<void>.value();
    }

    final flowGeneration = _oauthFlowGeneration;
    final predecessor = _oauthCompletionTail;
    late final Future<void> tracked;
    tracked = predecessor.then((_) async {
      if (!_isOAuthFlowGenerationCurrent(flowGeneration)) return;
      await _completeFromCode(code, flowGeneration: flowGeneration);
    });
    _oauthCompletions[code] = tracked;
    _oauthCompletionTail = tracked.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return tracked;
  }

  Future<void> _completeFromCode(
    String code, {
    required int flowGeneration,
  }) async {
    final kv = ref.read(keyValueStoreProvider);
    if (!_isOAuthFlowGenerationCurrent(flowGeneration)) return;
    // Capture the operation boundary when this queue item starts. Capturing at
    // enqueue time would make a valid callback stale after an earlier rejected
    // candidate completes.
    final requestEpoch = _epoch;
    final verifier = await _mutateCredentials(() => kv.read(_kPkceVerifier));
    if (!_isOAuthFlowCurrent(flowGeneration, requestEpoch)) return;
    if (verifier == null || verifier.isEmpty) {
      // `app_links` can redeliver an already-consumed callback. Without a
      // verifier it is not a new login attempt and must never tear down an
      // authenticated (or currently restoring) verified session.
      if (state is AuthAuthenticated ||
          state is AuthOfflineAuthenticated ||
          state is AuthLoading) {
        return;
      }
      state = const AuthUnauthenticated(error: 'PKCE verifier 없음(로그인 재시도 필요)');
      return;
    }
    var acceptedExchange = false;
    try {
      // A rejected PKCE candidate is not an authenticated-resource 401. Keep
      // this exchange off [AuthInterceptor] so it cannot refresh or invalidate
      // an otherwise valid session while the current callback remains queued.
      final data = await _authFlowClient.post<Map<String, dynamic>>(
        '/auth/oauth/token',
        body: {'code': code, 'code_verifier': verifier},
      );
      if (!_isOAuthFlowCurrent(flowGeneration, requestEpoch)) return;
      final access = data['access_token'];
      final refresh = data['refresh_token'];
      if (access is! String ||
          access.isEmpty ||
          refresh is! String ||
          refresh.isEmpty) {
        throw const FormatException('malformed OAuth token payload');
      }
      acceptedExchange = true;
      final epoch = ++_epoch;
      _bootstrapInFlight = null;
      final previousUser = await ref.read(verifiedSessionStoreProvider).read();
      if (!_isCurrent(epoch) ||
          !_isOAuthFlowGenerationCurrent(flowGeneration)) {
        return;
      }
      _invalidateCredentialBoundary();
      if (previousUser != null) {
        // Stop exposing A before any slow replacement cleanup or B activation.
        state = const AuthUnauthenticated();
      }
      var replacementRejected = false;
      if (previousUser != null) {
        replacementRejected = !await _revokePush(previousUser.id);
        if (!_isCurrent(epoch)) return;
      }
      final saved = await _mutateCredentials(() async {
        if (!_isCurrent(epoch)) return false;
        if (previousUser != null) {
          await _prepareLocalCredentialReplacement(previousUser.id);
          if (!_isCurrent(epoch)) return false;
          if (replacementRejected) return true;
        }
        await _store.save(access: access, refresh: refresh);
        return _isCurrent(epoch);
      });
      if (!saved) return;
      if (replacementRejected) {
        ref.read(pendingDeepLinkProvider.notifier).consume();
        state = const AuthUnauthenticated(
          error: '이전 계정의 알림 연결을 해제하지 못했어요. 다시 로그인해 주세요.',
        );
        return;
      }
      await bootstrapSession();
    } on ApiException catch (e) {
      _recordOAuthFailure(
        e.message,
        flowGeneration: flowGeneration,
        requestEpoch: requestEpoch,
      );
    } on Object {
      _recordOAuthFailure(
        '로그인 응답 형식을 확인하지 못했어요. 다시 시도해 주세요.',
        flowGeneration: flowGeneration,
        requestEpoch: requestEpoch,
      );
    } finally {
      // The callback has no client flow identifier. A rejected code can belong
      // to a superseded challenge, so only a valid token response consumes the
      // exact verifier used for that exchange.
      if (acceptedExchange && _isOAuthFlowGenerationCurrent(flowGeneration)) {
        await _mutateCredentials(() async {
          if (_isOAuthFlowGenerationCurrent(flowGeneration) &&
              await kv.read(_kPkceVerifier) == verifier) {
            await kv.delete(_kPkceVerifier);
          }
        });
      }
    }
  }

  void _recordOAuthFailure(
    String message, {
    required int flowGeneration,
    required int requestEpoch,
  }) {
    if (!_isOAuthFlowCurrent(flowGeneration, requestEpoch)) return;
    if (state is AuthAuthenticated ||
        state is AuthOfflineAuthenticated ||
        state is AuthLoading) {
      return;
    }
    state = AuthUnauthenticated(error: message);
  }

  void _resetOAuthCallbackQueue() {
    _oauthCompletionTail = Future<void>.value();
    _oauthCompletions.clear();
  }

  Future<void> logout() async {
    final liveOwnerKey = state.ownerKey;
    final ownerKey =
        liveOwnerKey ??
        (await ref.read(verifiedSessionStoreProvider).read())?.id;
    final credentialOwnerConfirmed =
        liveOwnerKey != null && liveOwnerKey == ownerKey;
    final epoch = ++_epoch;
    _bootstrapInFlight = null;
    _invalidateCredentialBoundary();
    // Drop the in-memory owner boundary before slow server/disk work so no
    // push or deep-link event can attach to the account being removed.
    state = const AuthUnauthenticated();
    ref.read(pendingDeepLinkProvider.notifier).consume();
    try {
      await _revokePush(
        ownerKey,
        credentialOwnerConfirmed: credentialOwnerConfirmed,
      );
      if (!_isCurrent(epoch)) return;
      await _mutateCredentials(() async {
        if (!_isCurrent(epoch)) return false;
        try {
          await ref.read(accountEpochStoreProvider).advance();
          if (ownerKey != null) {
            await ref.read(accountDataCleanerProvider).clearOwner(ownerKey);
          }
        } finally {
          await _store.clear();
          await ref.read(verifiedSessionStoreProvider).clear();
          await ref.read(keyValueStoreProvider).delete(_kPkceVerifier);
          await ref.read(pendingDeepLinkProvider.notifier).clearPersisted();
        }
        return _isCurrent(epoch);
      });
    } finally {
      if (_isCurrent(epoch)) {
        ref.read(pendingDeepLinkProvider.notifier).consume();
        state = const AuthUnauthenticated();
      }
    }
  }

  /// Runtime APIs use the same exact 401 boundary as cold-start `/users/me`.
  Future<void> invalidateUnauthorized([String? message]) async {
    final ownerKey =
        state.ownerKey ??
        (await ref.read(verifiedSessionStoreProvider).read())?.id;
    await _invalidateUnauthorizedOwner(ownerKey, message);
  }

  Future<void> _invalidateUnauthorizedOwner(
    String? ownerKey,
    String? message,
  ) async {
    final epoch = ++_epoch;
    _bootstrapInFlight = null;
    _invalidateCredentialBoundary();
    final terminal = AuthUnauthenticated(
      error: message ?? '세션이 만료되었어요. 다시 로그인해 주세요.',
    );
    state = terminal;
    ref.read(pendingDeepLinkProvider.notifier).consume();
    await _revokePush(ownerKey);
    if (!_isCurrent(epoch)) return;
    final cleared = await _mutateCredentials(() async {
      if (!_isCurrent(epoch)) return false;
      await _clearVerifiedLocalBoundary(ownerKey);
      return _isCurrent(epoch);
    });
    if (cleared) {
      state = terminal;
    }
  }

  /// Terminal signal from [AuthInterceptor] after it has cleared an
  /// authoritative rejected credential. The request-captured durable/live
  /// tuple prevents a late A rejection from invalidating a replacement B (or
  /// a new login for the same owner).
  Future<void> invalidateUnauthorizedIfCurrentSession(
    Object? capturedSessionEpoch,
  ) async {
    if (capturedSessionEpoch == null ||
        !await _isCapturedSessionCurrent(capturedSessionEpoch)) {
      return;
    }
    final ownerKey =
        state.ownerKey ??
        (await ref.read(verifiedSessionStoreProvider).read())?.id;
    if (ownerKey == null ||
        !await _isCapturedSessionCurrent(capturedSessionEpoch)) {
      return;
    }
    await _invalidateUnauthorizedOwner(ownerKey, null);
  }

  Future<bool> _isCapturedSessionCurrent(Object captured) async {
    final current = (
      durable: await ref.read(accountEpochStoreProvider).current(),
      credential: ref.read(credentialMutationCoordinatorProvider).generation,
    );
    return ref.mounted && captured == current;
  }

  Future<void> _clearVerifiedLocalBoundary([String? knownOwner]) async {
    final sessionStore = ref.read(verifiedSessionStoreProvider);
    final ownerKey = knownOwner ?? (await sessionStore.read())?.id;
    try {
      await ref.read(accountEpochStoreProvider).advance();
      if (ownerKey != null) {
        await ref.read(accountDataCleanerProvider).clearOwner(ownerKey);
      }
    } finally {
      await _store.clear();
      await sessionStore.clear();
      await ref.read(pendingDeepLinkProvider.notifier).clearPersisted();
    }
  }

  Future<bool> _revokePush(
    String? ownerKey, {
    bool credentialOwnerConfirmed = false,
  }) async {
    if (ownerKey == null) return true;
    try {
      await ref
          .read(deviceRegistrarProvider)
          .unregister(
            ownerKey,
            credentialOwnerConfirmed: credentialOwnerConfirmed,
          );
      return true;
    } on Object {
      // Credential and owner cleanup must remain fail-closed locally.
      return false;
    }
  }

  /// Clears an established account before a replacement credential can be
  /// stored. The durable epoch advances first so in-flight A requests cannot
  /// pass the interceptor rotation guard with B's token.
  Future<void> _prepareLocalCredentialReplacement(String ownerKey) async {
    try {
      await ref.read(accountEpochStoreProvider).advance();
      await ref.read(accountDataCleanerProvider).clearOwner(ownerKey);
    } finally {
      await _store.clear();
      await ref.read(verifiedSessionStoreProvider).clear();
      await ref.read(pendingDeepLinkProvider.notifier).clearPersisted();
    }
    ref.read(pendingDeepLinkProvider.notifier).consume();
  }

  bool _isCurrent(int epoch) => ref.mounted && epoch == _epoch;

  bool _isOAuthFlowGenerationCurrent(int generation) =>
      ref.mounted && generation == _oauthFlowGeneration;

  bool _isOAuthFlowCurrent(int generation, int epoch) =>
      ref.mounted && generation == _oauthFlowGeneration && epoch == _epoch;

  void _invalidateCredentialBoundary() {
    ref.read(credentialMutationCoordinatorProvider).invalidate();
  }

  Future<T> _mutateCredentials<T>(Future<T> Function() mutation) {
    return ref.read(credentialMutationCoordinatorProvider).run(mutation);
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

final currentOwnerKeyProvider = Provider<String?>(
  (ref) => ref.watch(authControllerProvider.select((auth) => auth.ownerKey)),
);
