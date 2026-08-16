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
  var _lifecycleEpoch = 0;

  /// Called only after the authenticated user has completed explicit consent.
  /// Permission is requested before FCM token creation/registration.
  Future<void> activate(String ownerKey) {
    _activeOwner = ownerKey;
    final epoch = ++_lifecycleEpoch;
    _ensureRefreshSubscription();
    return _serialize(() async {
      if (!_isCurrent(ownerKey, epoch)) return;
      final lifecycle = _push is PushTokenLifecycleService
          ? _push as PushTokenLifecycleService
          : null;
      if (lifecycle != null && !await lifecycle.requestPermission()) return;
      if (!_isCurrent(ownerKey, epoch)) return;
      final token = await _push.getToken();
      if (token == null || token.isEmpty || !_isCurrent(ownerKey, epoch)) {
        return;
      }
      await _registerToken(ownerKey, token, epoch: epoch);
    });
  }

  Future<void> register([String ownerKey = '__legacy__']) async {
    final token = await _push.getToken();
    if (token == null || token.isEmpty) return;
    await _registerToken(ownerKey, token);
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
    if (_activeOwner == ownerKey) _activeOwner = null;
    _lifecycleEpoch += 1;
    return _serialize(() async {
      String? token;
      try {
        token = (await _registrations.read(
          ownerKey,
          _bucket,
          _platform,
        ))?.payload;
      } on Object {
        // A damaged/unavailable local index must not skip FCM invalidation.
      }
      if (token == null || token.isEmpty) {
        try {
          token = await _push.getToken();
        } on Object {
          // deleteToken below is still required when token lookup fails.
        }
      }
      try {
        if (token != null && token.isNotEmpty) {
          await _bestEffortServerUnregister(token);
        }
      } finally {
        final lifecycle = _push is PushTokenLifecycleService
            ? _push as PushTokenLifecycleService
            : null;
        if (lifecycle != null) {
          try {
            await lifecycle.deleteToken();
          } on Object {
            // Local account cleanup must continue if the platform rejects it.
          }
        }
        try {
          await _registrations.delete(ownerKey, _bucket, _platform);
        } on Object {
          // AccountDataCleaner remains the final owner-wide deletion boundary.
        }
      }
    });
  }

  Future<void> _bestEffortServerUnregister(String token) async {
    try {
      await _client.delete<dynamic>(
        '/notifications/devices',
        body: {'token': token, 'platform': _platform},
      );
    } on Object {
      // A 401/offline server cannot prevent local token invalidation.
    }
  }

  void _ensureRefreshSubscription() {
    if (_refreshSubscription != null || _push is! PushTokenLifecycleService) {
      return;
    }
    final lifecycle = _push as PushTokenLifecycleService;
    _refreshSubscription = lifecycle.tokenRefresh.listen((token) {
      final owner = _activeOwner;
      final epoch = _lifecycleEpoch;
      if (owner == null || token.isEmpty) return;
      unawaited(
        _serialize(() async {
          if (!_isCurrent(owner, epoch)) return;
          await _registerToken(owner, token, epoch: epoch);
        }).catchError((_) {}),
      );
    });
  }

  bool _isCurrent(String ownerKey, int epoch) =>
      _activeOwner == ownerKey && _lifecycleEpoch == epoch;

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final result = _operationTail.then((_) => operation());
    _operationTail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  Future<void> dispose() async {
    await _refreshSubscription?.cancel();
    _refreshSubscription = null;
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
