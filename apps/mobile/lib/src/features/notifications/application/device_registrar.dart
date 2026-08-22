import 'dart:async';
import 'dart:convert';

import 'package:dp_core/dp_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/api_providers.dart';
import '../../../services/push_service.dart';
import '../../../data/key_value_store.dart';
import '../../../data/owner_data_store.dart';

/// 인증 진입 후 FCM 디바이스 토큰을 백엔드(`POST /notifications/devices`)에 등록한다(트랙 C).
/// 타깃 푸시 발송의 전제. 토큰이 없으면(목/미초기화) 아무것도 하지 않는다.
/// 등록 실패는 호출측(app.dart)이 삼킨다 — 부가 기능이라 인증/UX를 막지 않는다.
class DeviceRegistrar {
  DeviceRegistrar(
    this._client,
    this._push,
    this._platform, [
    OwnerDataStore? registrations,
    KeyValueStore? pendingRevocations,
  ]) : _registrations = registrations ?? InMemoryOwnerDataStore(),
       _pendingRevocations = pendingRevocations ?? InMemoryKeyValueStore();

  final ApiClient _client;
  final PushService _push;
  final String _platform; // 'ANDROID' | 'IOS'
  final OwnerDataStore _registrations;
  final KeyValueStore _pendingRevocations;
  static const _bucket = 'push-registration-v1';
  static const pendingRevocationsStorageKey =
      'leva.mobile.push_pending_revocations.v1';
  StreamSubscription<String>? _refreshSubscription;
  Future<void> _operationTail = Future<void>.value();
  String? _activeOwner;
  String? _approvedOwner;
  int? _approvedEpoch;
  String? _subscriptionOwner;
  int? _subscriptionEpoch;
  var _lifecycleEpoch = 0;

  /// Called only after the authenticated user has completed explicit consent.
  /// Permission is requested before FCM token creation/registration.
  Future<void> activate(String ownerKey) async {
    _activeOwner = ownerKey;
    final epoch = ++_lifecycleEpoch;
    // Invalidate the old permission grant synchronously. A refresh callback
    // already queued by the previous account must fail before async cleanup.
    _approvedOwner = null;
    _approvedEpoch = null;
    await _cancelRefreshSubscription();
    if (!_isCurrent(ownerKey, epoch)) return;
    await _serialize(() => _drainPendingRevocations(credentialOwner: ownerKey));
    if (!_isCurrent(ownerKey, epoch)) return;
    final lifecycle = _push is PushTokenLifecycleService
        ? _push as PushTokenLifecycleService
        : null;
    try {
      if (lifecycle != null && !await lifecycle.requestPermission()) {
        if (_clearDeniedActivation(ownerKey, epoch)) {
          await _serialize(
            () => _unregisterNow(
              ownerKey,
              deletePlatformToken: true,
              credentialOwnerConfirmed: true,
            ),
          );
        }
        return;
      }
    } on Object {
      if (_clearDeniedActivation(ownerKey, epoch)) {
        await _serialize(
          () => _unregisterNow(
            ownerKey,
            deletePlatformToken: true,
            credentialOwnerConfirmed: true,
          ),
        );
      }
      rethrow;
    }
    if (!_isCurrent(ownerKey, epoch)) return;
    _approvedOwner = ownerKey;
    _approvedEpoch = epoch;
    final registration = _serialize(() async {
      if (!_isApproved(ownerKey, epoch)) return;
      final token = await _push.getToken();
      if (token == null || token.isEmpty || !_isApproved(ownerKey, epoch)) {
        return;
      }
      await _registerToken(ownerKey, token, epoch: epoch);
    });
    // `_serialize` updates the tail synchronously, so even a synchronous
    // refresh emission is ordered after the initial approved registration.
    _ensureRefreshSubscription(ownerKey, epoch);
    await registration;
  }

  Future<void> _registerToken(
    String ownerKey,
    String token, {
    int? epoch,
  }) async {
    if (epoch != null && !_isCurrent(ownerKey, epoch)) return;
    final previous = await _registrations.read(ownerKey, _bucket, _platform);
    if (previous?.payload == token) return;
    if (epoch != null && !_isCurrent(ownerKey, epoch)) return;
    if (previous != null) {
      // Token rotation must not lose the only durable handle for the previous
      // backend registration. A failed DELETE is retried on the next
      // activation/logout; registering and persisting the replacement would
      // otherwise orphan the old token on the server.
      await _serverUnregister(previous.payload, suppressTerminal: false);
    }
    if (epoch != null && !_isApproved(ownerKey, epoch)) return;
    final pending = _PendingRevocation(
      ownerKey: ownerKey,
      platform: _platform,
      token: token,
    );
    // POST success can race process death, owner replacement, or a local row
    // write failure. Persist the exact cleanup handle before the remote side
    // effect so none of those boundaries can orphan the server registration.
    await _stagePendingRevocation(pending);
    await _client.post<dynamic>(
      '/notifications/devices',
      body: {'token': token, 'platform': _platform},
    );
    if (epoch != null && !_isCurrent(ownerKey, epoch)) {
      await _cleanupStalePost(ownerKey, token);
      return;
    }
    await _registrations.write(ownerKey, _bucket, _platform, token);
    await _completePendingRevocation(pending);
  }

  /// Revokes the server registration while the bearer credential still
  /// exists, then invalidates the platform token even if the server is down.
  Future<void> unregister(String ownerKey, {bool? credentialOwnerConfirmed}) {
    final capturedCredentialProof =
        credentialOwnerConfirmed ??
        (_activeOwner == ownerKey && _approvedOwner == ownerKey);
    final shouldDeletePlatformToken =
        _activeOwner == null || _activeOwner == ownerKey;
    if (_activeOwner == ownerKey || _approvedOwner == ownerKey) {
      _activeOwner = null;
      _approvedOwner = null;
      _approvedEpoch = null;
      _lifecycleEpoch += 1;
    }
    return _serialize(
      () => _unregisterNow(
        ownerKey,
        deletePlatformToken: shouldDeletePlatformToken,
        credentialOwnerConfirmed: capturedCredentialProof,
      ),
    );
  }

  Future<void> _unregisterNow(
    String ownerKey, {
    required bool deletePlatformToken,
    required bool credentialOwnerConfirmed,
  }) async {
    await _cancelRefreshSubscription(ownerKey: ownerKey);
    Object? failure;
    StackTrace? failureStack;
    void capture(Object error, StackTrace stackTrace) {
      failure ??= error;
      failureStack ??= stackTrace;
    }

    OwnerDataRecord? registration;
    try {
      registration = await _registrations.read(ownerKey, _bucket, _platform);
    } on Object catch (error, stackTrace) {
      capture(error, stackTrace);
      // A damaged/unavailable local index must not skip FCM invalidation.
    }

    final registrationRevocation = registration == null
        ? null
        : _PendingRevocation(
            ownerKey: ownerKey,
            platform: _platform,
            token: registration.payload,
            registrationUpdatedAt: registration.updatedAt,
          );
    try {
      await _drainPendingRevocations(
        credentialOwner: credentialOwnerConfirmed ? ownerKey : null,
        allowPlatformInvalidation: deletePlatformToken,
        skipIdentity: registrationRevocation?.identity,
      );
    } on Object catch (error, stackTrace) {
      capture(error, stackTrace);
    }

    var platformWasAttempted = false;
    if (registrationRevocation != null &&
        registrationRevocation.token.isNotEmpty) {
      try {
        await _stagePendingRevocation(registrationRevocation);
        final attempt = await _attemptPendingRevocation(
          registrationRevocation,
          credentialOwner: credentialOwnerConfirmed ? ownerKey : null,
          allowPlatformInvalidation: deletePlatformToken,
          alwaysInvalidatePlatform: deletePlatformToken,
        );
        platformWasAttempted = attempt.platformAttempted;
        if (attempt.confirmed) {
          await _completePendingRevocation(
            registrationRevocation,
            removeRegistration: true,
          );
        }
        if (attempt.failure != null) {
          capture(attempt.failure!, attempt.failureStack!);
        }
      } on Object catch (error, stackTrace) {
        capture(error, stackTrace);
      }
    }
    if (deletePlatformToken && !platformWasAttempted) {
      final invalidation = await _invalidatePlatformToken();
      if (invalidation.failure != null) {
        capture(invalidation.failure!, invalidation.failureStack!);
      }
    }
    if (failure != null) {
      Error.throwWithStackTrace(failure!, failureStack!);
    }
  }

  Future<void> _serverUnregister(
    String token, {
    required bool suppressTerminal,
  }) async {
    await _client.delete<dynamic>(
      '/notifications/devices',
      body: {'token': token, 'platform': _platform},
      extra: suppressTerminal
          ? {AuthInterceptor.suppressTerminalNotificationExtra: true}
          : null,
    );
  }

  Future<void> _cleanupStalePost(String ownerKey, String token) async {
    final pending = _PendingRevocation(
      ownerKey: ownerKey,
      platform: _platform,
      token: token,
    );
    // The durable handle is established before either cleanup call. A stale
    // POST has no owner-scoped registration row to fall back to after restart.
    await _stagePendingRevocation(pending);
    final attempt = await _attemptPendingRevocation(
      pending,
      credentialOwner: _activeOwner,
      allowPlatformInvalidation: true,
    );
    if (attempt.confirmed) {
      await _completePendingRevocation(pending, removeRegistration: true);
    }
    // Once the tombstone is durable, a stale caller need not surface cleanup
    // availability; the next activate/unregister retries it before registration.
  }

  Future<void> _drainPendingRevocations({
    required String? credentialOwner,
    bool allowPlatformInvalidation = true,
    String? skipIdentity,
  }) async {
    final pending = await _readPendingRevocations();
    for (final revocation in pending) {
      if (revocation.identity == skipIdentity) continue;
      final attempt = await _attemptPendingRevocation(
        revocation,
        credentialOwner: credentialOwner,
        allowPlatformInvalidation: allowPlatformInvalidation,
      );
      if (!attempt.confirmed) {
        final error =
            attempt.failure ??
            StateError('pending push revocation could not be confirmed');
        Error.throwWithStackTrace(
          error,
          attempt.failureStack ?? StackTrace.current,
        );
      }
      await _completePendingRevocation(revocation, removeRegistration: true);
    }
  }

  Future<_RevocationAttempt> _attemptPendingRevocation(
    _PendingRevocation revocation, {
    required String? credentialOwner,
    required bool allowPlatformInvalidation,
    bool alwaysInvalidatePlatform = false,
  }) async {
    var serverConfirmed = false;
    Object? failure;
    StackTrace? failureStack;
    void capture(Object error, StackTrace stackTrace) {
      failure ??= error;
      failureStack ??= stackTrace;
    }

    // DELETE is owner-scoped but idempotently returns 204 for a token owned by
    // somebody else. Only a caller-captured same-owner credential can turn the
    // HTTP success into authoritative revocation evidence.
    if (credentialOwner == revocation.ownerKey) {
      try {
        await _serverUnregister(revocation.token, suppressTerminal: true);
        serverConfirmed = true;
      } on Object catch (error, stackTrace) {
        capture(error, stackTrace);
      }
    }

    var platformConfirmed = false;
    var platformAttempted = false;
    if (allowPlatformInvalidation &&
        (alwaysInvalidatePlatform || !serverConfirmed)) {
      final invalidation = await _invalidatePlatformToken();
      platformAttempted = invalidation.attempted;
      platformConfirmed = invalidation.confirmed;
      if (invalidation.failure != null) {
        capture(invalidation.failure!, invalidation.failureStack!);
      }
    }

    return _RevocationAttempt(
      confirmed: serverConfirmed || platformConfirmed,
      platformAttempted: platformAttempted,
      failure: failure,
      failureStack: failureStack,
    );
  }

  Future<_PlatformInvalidation> _invalidatePlatformToken() async {
    if (_push is! PushTokenLifecycleService) {
      return const _PlatformInvalidation(attempted: false, confirmed: false);
    }
    final lifecycle = _push as PushTokenLifecycleService;
    Object? failure;
    StackTrace? failureStack;
    try {
      await lifecycle.disableAutoInit();
    } on Object catch (error, stackTrace) {
      failure = error;
      failureStack = stackTrace;
      // Token deletion still runs so an auto-init platform failure cannot
      // retain the current account's local identifier.
    }
    try {
      await lifecycle.deleteToken();
      return _PlatformInvalidation(
        attempted: true,
        confirmed: true,
        failure: failure,
        failureStack: failureStack,
      );
    } on Object catch (error, stackTrace) {
      failure ??= error;
      failureStack ??= stackTrace;
      return _PlatformInvalidation(
        attempted: true,
        confirmed: false,
        failure: failure,
        failureStack: failureStack,
      );
    }
  }

  Future<void> _stagePendingRevocation(_PendingRevocation pending) async {
    final current = await _readPendingRevocations();
    final next = <_PendingRevocation>[
      for (final item in current)
        if (item.identity != pending.identity) item,
      pending,
    ];
    await _writePendingRevocations(next);
  }

  Future<void> _completePendingRevocation(
    _PendingRevocation pending, {
    bool removeRegistration = false,
  }) async {
    final current = await _readPendingRevocations();
    await _writePendingRevocations(
      current.where((item) => item.identity != pending.identity).toList(),
    );
    if (removeRegistration) {
      final exact = pending.registrationUpdatedAt == null
          ? await _registrations.read(
              pending.ownerKey,
              _bucket,
              pending.platform,
            )
          : null;
      final updatedAt =
          pending.registrationUpdatedAt ??
          (exact?.payload == pending.token ? exact?.updatedAt : null);
      if (updatedAt == null) return;
      await _registrations.deleteIfMatches(
        pending.ownerKey,
        _bucket,
        pending.platform,
        payload: pending.token,
        updatedAt: updatedAt,
      );
    }
  }

  Future<List<_PendingRevocation>> _readPendingRevocations() async {
    final raw = await _pendingRevocations.read(pendingRevocationsStorageKey);
    if (raw == null) return const [];
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic> || decoded['revocations'] is! List) {
      throw const FormatException('invalid pending push revocations');
    }
    return (decoded['revocations'] as List<dynamic>)
        .map((item) => _PendingRevocation.fromJson(item))
        .toList(growable: false);
  }

  Future<void> _writePendingRevocations(List<_PendingRevocation> pending) {
    if (pending.isEmpty) {
      return _pendingRevocations.delete(pendingRevocationsStorageKey);
    }
    pending.sort((a, b) => a.identity.compareTo(b.identity));
    return _pendingRevocations.write(
      pendingRevocationsStorageKey,
      jsonEncode({
        'version': 1,
        'revocations': pending.map((item) => item.toJson()).toList(),
      }),
    );
  }

  void _ensureRefreshSubscription(String ownerKey, int epoch) {
    if (_refreshSubscription != null || _push is! PushTokenLifecycleService) {
      return;
    }
    final lifecycle = _push as PushTokenLifecycleService;
    _subscriptionOwner = ownerKey;
    _subscriptionEpoch = epoch;
    _refreshSubscription = lifecycle.tokenRefresh.listen((token) {
      if (token.isEmpty || !_isRefreshCurrent(ownerKey, epoch)) return;
      unawaited(
        _serialize(() async {
          if (!_isRefreshCurrent(ownerKey, epoch)) return;
          await _registerToken(ownerKey, token, epoch: epoch);
        }).catchError((_) {}),
      );
    });
  }

  Future<void> _cancelRefreshSubscription({String? ownerKey}) async {
    if (ownerKey != null && _subscriptionOwner != ownerKey) return;
    final subscription = _refreshSubscription;
    _refreshSubscription = null;
    _subscriptionOwner = null;
    _subscriptionEpoch = null;
    await subscription?.cancel();
  }

  bool _clearDeniedActivation(String ownerKey, int epoch) {
    if (!_isCurrent(ownerKey, epoch)) return false;
    _activeOwner = null;
    _approvedOwner = null;
    _approvedEpoch = null;
    _lifecycleEpoch += 1;
    return true;
  }

  bool _isCurrent(String ownerKey, int epoch) =>
      _activeOwner == ownerKey && _lifecycleEpoch == epoch;

  bool _isApproved(String ownerKey, int epoch) =>
      _isCurrent(ownerKey, epoch) &&
      _approvedOwner == ownerKey &&
      _approvedEpoch == epoch;

  bool _isRefreshCurrent(String ownerKey, int epoch) =>
      _isApproved(ownerKey, epoch) &&
      _subscriptionOwner == ownerKey &&
      _subscriptionEpoch == epoch;

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final result = _operationTail.then((_) => operation());
    _operationTail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  Future<void> dispose() async {
    _activeOwner = null;
    _approvedOwner = null;
    _approvedEpoch = null;
    _lifecycleEpoch += 1;
    await _cancelRefreshSubscription();
  }
}

String _platformTag() =>
    defaultTargetPlatform == TargetPlatform.iOS ? 'IOS' : 'ANDROID';

final deviceRegistrarProvider = Provider<DeviceRegistrar>((ref) {
  final registrar = DeviceRegistrar(
    ref.watch(apiClientProvider),
    ref.watch(pushServiceProvider),
    _platformTag(),
    ref.watch(ownerDataStoreProvider),
    ref.watch(keyValueStoreProvider),
  );
  ref.onDispose(() => unawaited(registrar.dispose()));
  return registrar;
});

final class _PendingRevocation {
  const _PendingRevocation({
    required this.ownerKey,
    required this.platform,
    required this.token,
    this.registrationUpdatedAt,
  });

  factory _PendingRevocation.fromJson(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('invalid pending push revocation');
    }
    final ownerKey = value['ownerKey'];
    final platform = value['platform'];
    final token = value['token'];
    final updatedAtRaw = value['registrationUpdatedAt'];
    if (ownerKey is! String ||
        ownerKey.isEmpty ||
        platform is! String ||
        platform.isEmpty ||
        token is! String ||
        token.isEmpty ||
        (updatedAtRaw != null && updatedAtRaw is! String)) {
      throw const FormatException('invalid pending push revocation');
    }
    return _PendingRevocation(
      ownerKey: ownerKey,
      platform: platform,
      token: token,
      registrationUpdatedAt: updatedAtRaw == null
          ? null
          : DateTime.parse(updatedAtRaw).toUtc(),
    );
  }

  final String ownerKey;
  final String platform;
  final String token;
  final DateTime? registrationUpdatedAt;

  String get identity => '$ownerKey\u0000$platform\u0000$token';

  Map<String, dynamic> toJson() => {
    'ownerKey': ownerKey,
    'platform': platform,
    'token': token,
    if (registrationUpdatedAt != null)
      'registrationUpdatedAt': registrationUpdatedAt!.toIso8601String(),
  };
}

final class _RevocationAttempt {
  const _RevocationAttempt({
    required this.confirmed,
    required this.platformAttempted,
    this.failure,
    this.failureStack,
  });

  final bool confirmed;
  final bool platformAttempted;
  final Object? failure;
  final StackTrace? failureStack;
}

final class _PlatformInvalidation {
  const _PlatformInvalidation({
    required this.attempted,
    required this.confirmed,
    this.failure,
    this.failureStack,
  });

  final bool attempted;
  final bool confirmed;
  final Object? failure;
  final StackTrace? failureStack;
}
