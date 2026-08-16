import 'dart:async';

import 'package:dp_core/dp_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/api_providers.dart';
import '../../../services/push_service.dart';
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
  ]) : _registrations = registrations ?? InMemoryOwnerDataStore();

  final ApiClient _client;
  final PushService _push;
  final String _platform; // 'ANDROID' | 'IOS'
  final OwnerDataStore _registrations;
  static const _bucket = 'push-registration-v1';
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
    final lifecycle = _push is PushTokenLifecycleService
        ? _push as PushTokenLifecycleService
        : null;
    try {
      if (lifecycle != null && !await lifecycle.requestPermission()) {
        if (_clearDeniedActivation(ownerKey, epoch)) {
          await _serialize(
            () => _unregisterNow(ownerKey, deletePlatformToken: true),
          );
        }
        return;
      }
    } on Object {
      if (_clearDeniedActivation(ownerKey, epoch)) {
        await _serialize(
          () => _unregisterNow(ownerKey, deletePlatformToken: true),
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
      await _bestEffortServerUnregister(previous.payload);
    }
    await _client.post<dynamic>(
      '/notifications/devices',
      body: {'token': token, 'platform': _platform},
    );
    if (epoch != null && !_isCurrent(ownerKey, epoch)) {
      await _bestEffortServerUnregister(token);
      return;
    }
    await _registrations.write(ownerKey, _bucket, _platform, token);
  }

  /// Revokes the server registration while the bearer credential still
  /// exists, then invalidates the platform token even if the server is down.
  Future<void> unregister(String ownerKey) {
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
      ),
    );
  }

  Future<void> _unregisterNow(
    String ownerKey, {
    required bool deletePlatformToken,
  }) async {
    await _cancelRefreshSubscription(ownerKey: ownerKey);
    Object? failure;
    StackTrace? failureStack;
    void capture(Object error, StackTrace stackTrace) {
      failure ??= error;
      failureStack ??= stackTrace;
    }

    String? token;
    try {
      token = (await _registrations.read(
        ownerKey,
        _bucket,
        _platform,
      ))?.payload;
    } on Object catch (error, stackTrace) {
      capture(error, stackTrace);
      // A damaged/unavailable local index must not skip FCM invalidation.
    }
    if (token != null && token.isNotEmpty) {
      try {
        await _serverUnregister(token);
      } on Object catch (error, stackTrace) {
        capture(error, stackTrace);
      }
    }
    final lifecycle = _push is PushTokenLifecycleService
        ? _push as PushTokenLifecycleService
        : null;
    if (lifecycle != null && deletePlatformToken) {
      try {
        await lifecycle.deleteToken();
      } on Object catch (error, stackTrace) {
        capture(error, stackTrace);
        // Local account cleanup must continue if the platform rejects it.
      }
    }
    try {
      await _registrations.delete(ownerKey, _bucket, _platform);
    } on Object catch (error, stackTrace) {
      capture(error, stackTrace);
      // AccountDataCleaner remains the final owner-wide deletion boundary.
    }
    if (failure != null) {
      Error.throwWithStackTrace(failure!, failureStack!);
    }
  }

  Future<void> _serverUnregister(String token) {
    return _client.delete<dynamic>(
      '/notifications/devices',
      body: {'token': token, 'platform': _platform},
    );
  }

  Future<void> _bestEffortServerUnregister(String token) async {
    try {
      await _serverUnregister(token);
    } on Object {
      // A 401/offline server cannot prevent local token invalidation.
    }
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
  );
  ref.onDispose(() => unawaited(registrar.dispose()));
  return registrar;
});
