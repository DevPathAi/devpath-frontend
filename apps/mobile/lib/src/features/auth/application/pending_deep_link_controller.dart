import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/api_providers.dart';
import '../../mission/state/mobile_mission_route.dart';
import 'account_epoch_store.dart';

typedef PendingDeepLinkClock = DateTime Function();

final pendingDeepLinkClockProvider = Provider<PendingDeepLinkClock>(
  (ref) => DateTime.now,
);

/// Persists one validated route across the external PKCE/web-activation hop.
class PendingDeepLinkController extends Notifier<String?> {
  static const storageKey = 'leva.mobile.pending_route.v1';
  static const consumedStorageKey = 'leva.mobile.pending_route.consumed.v1';
  static const ttl = Duration(minutes: 15);
  var _generation = 0;
  Future<void> _storageTail = Future<void>.value();
  static final _captureIdRandom = Random.secure();

  int get generation => _generation;

  @override
  String? build() {
    Future.microtask(restore);
    return null;
  }

  Future<void> restore() async {
    final generation = _generation;
    final snapshot = await _mutateStorage(() async {
      final store = ref.read(keyValueStoreProvider);
      return (
        pending: await store.read(storageKey),
        consumed: await store.read(consumedStorageKey),
      );
    });
    if (!ref.mounted || generation != _generation) return;
    final stored = snapshot.pending;
    final consumed = snapshot.consumed;
    if (stored == null) {
      state = null;
      if (consumed != null) {
        await _mutateStorage(_clearConsumedMarkerBestEffort);
      }
      return;
    }
    if (stored == consumed) {
      state = null;
      await _mutateStorage(() => _deleteConsumedPendingBestEffort(stored));
      return;
    }
    try {
      final json = jsonDecode(stored) as Map<String, dynamic>;
      final route = MobileMissionRoute.tryParse(
        json['location'] as String? ?? '',
      );
      final capturedAt = DateTime.parse(json['capturedAt'] as String).toUtc();
      final recordEpoch = (json['ownerEpoch'] as num).toInt();
      final currentEpoch = await ref.read(accountEpochStoreProvider).current();
      if (!ref.mounted || generation != _generation) return;
      final age = ref
          .read(pendingDeepLinkClockProvider)()
          .toUtc()
          .difference(capturedAt);
      if (route == null ||
          recordEpoch != currentEpoch ||
          age.isNegative ||
          age >= ttl) {
        throw const FormatException('expired or foreign pending route');
      }
      state = route.location;
    } on Object {
      state = null;
      await _deleteIfUnchanged(stored);
    }
  }

  Future<bool> capture(String location) async {
    final route = MobileMissionRoute.tryParse(location);
    if (route == null) return false;
    final generation = ++_generation;
    state = route.location;
    final epoch = await ref.read(accountEpochStoreProvider).current();
    if (!ref.mounted || generation != _generation) return false;
    final record = jsonEncode({
      'location': route.location,
      'ownerEpoch': epoch,
      'generation': generation,
      'captureId': base64UrlEncode(
        List<int>.generate(16, (_) => _captureIdRandom.nextInt(256)),
      ),
      'capturedAt': ref
          .read(pendingDeepLinkClockProvider)()
          .toUtc()
          .toIso8601String(),
    });
    await _mutateStorage(() async {
      await _clearConsumedMarkerBestEffort();
      await ref.read(keyValueStoreProvider).write(storageKey, record);
    });
    final latestEpoch = await ref.read(accountEpochStoreProvider).current();
    if (!ref.mounted || generation != _generation || latestEpoch != epoch) {
      await _deleteIfUnchanged(record);
      return false;
    }
    // An auto-restore scheduled by build may have observed the pre-capture
    // empty store while this capture was awaiting the account epoch.
    state = route.location;
    return true;
  }

  void consume() {
    unawaited(
      consumeAndWait().catchError((Object error, StackTrace stackTrace) {
        // Persistent storage failure is observable but never leaks through an
        // unawaited zone. Epoch/TTL still fail closed across account changes.
        developer.log(
          'pending deep-link delete failed after retries',
          name: 'devpath.mobile.pending_link',
          error: error,
          stackTrace: stackTrace,
        );
      }),
    );
  }

  Future<void> consumeAndWait() {
    final scheduledGeneration = _generation;
    return _mutateStorage(() async {
      if (!ref.mounted || scheduledGeneration != _generation) return;
      final store = ref.read(keyValueStoreProvider);
      final stored = await store.read(storageKey);
      if (!ref.mounted || scheduledGeneration != _generation) return;
      if (stored == null) {
        _generation += 1;
        state = null;
        await _clearConsumedMarkerOrThrow();
        return;
      }

      // The exact durable record is fenced as consumed before the in-memory
      // route is cleared. If this write fails, callers can retry and a restart
      // is still allowed to restore the route.
      await store.write(consumedStorageKey, stored);
      if (!ref.mounted || scheduledGeneration != _generation) return;
      _generation += 1;
      state = null;
      await _deleteConsumedPendingOrThrow(stored);
    });
  }

  /// Authoritative local-session cleanup boundary. Both the live pending
  /// record and its exact consumed marker are handled by the same serialized
  /// protocol so direct callers cannot leave replayable residue behind.
  Future<void> clearPersisted() => consumeAndWait();

  bool consumeIfMatches(
    String expectedLocation, {
    required int expectedGeneration,
  }) {
    if (state != expectedLocation || _generation != expectedGeneration) {
      return false;
    }
    consume();
    return true;
  }

  Future<void> _deleteIfUnchanged(String? expected) {
    if (expected == null) return Future<void>.value();
    return _mutateStorage(() async {
      final store = ref.read(keyValueStoreProvider);
      if (await store.read(storageKey) == expected) {
        await store.delete(storageKey);
        await _clearConsumedMarkerBestEffort();
      }
    });
  }

  Future<void> _deleteConsumedPendingOrThrow(String expected) async {
    final store = ref.read(keyValueStoreProvider);
    Object? lastError;
    StackTrace? lastStack;
    for (var attempt = 0; attempt < 3; attempt += 1) {
      if (await store.read(storageKey) != expected) {
        await _deleteConsumedMarkerIfMatches(expected);
        return;
      }
      try {
        await store.delete(storageKey);
        await _deleteConsumedMarkerIfMatches(expected);
        return;
      } on Object catch (error, stackTrace) {
        lastError = error;
        lastStack = stackTrace;
      }
    }
    Error.throwWithStackTrace(lastError!, lastStack!);
  }

  Future<void> _deleteConsumedPendingBestEffort(String expected) async {
    try {
      await _deleteConsumedPendingOrThrow(expected);
    } on Object {
      // The exact tombstone remains durable, so later restores keep rejecting
      // this consumed record and retry its physical deletion.
    }
  }

  Future<void> _deleteConsumedMarkerIfMatches(String expected) async {
    final store = ref.read(keyValueStoreProvider);
    if (await store.read(consumedStorageKey) == expected) {
      await store.delete(consumedStorageKey);
    }
  }

  Future<void> _clearConsumedMarkerBestEffort() async {
    try {
      await _clearConsumedMarkerOrThrow();
    } on Object {
      // An older exact-record marker cannot suppress a newer record.
    }
  }

  Future<void> _clearConsumedMarkerOrThrow() async {
    final store = ref.read(keyValueStoreProvider);
    if (await store.read(consumedStorageKey) == null) return;
    Object? lastError;
    StackTrace? lastStack;
    for (var attempt = 0; attempt < 3; attempt += 1) {
      try {
        await store.delete(consumedStorageKey);
        return;
      } on Object catch (error, stackTrace) {
        lastError = error;
        lastStack = stackTrace;
      }
    }
    Error.throwWithStackTrace(lastError!, lastStack!);
  }

  Future<T> _mutateStorage<T>(Future<T> Function() operation) {
    final result = _storageTail.then((_) => operation());
    _storageTail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }
}

final pendingDeepLinkProvider =
    NotifierProvider<PendingDeepLinkController, String?>(
      PendingDeepLinkController.new,
    );
