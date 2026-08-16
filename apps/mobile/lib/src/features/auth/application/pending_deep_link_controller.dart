import 'dart:async';
import 'dart:convert';

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
  static const ttl = Duration(minutes: 15);
  var _generation = 0;
  Future<void> _storageTail = Future<void>.value();

  @override
  String? build() {
    Future.microtask(restore);
    return null;
  }

  Future<void> restore() async {
    final generation = _generation;
    final stored = await _mutateStorage(
      () => ref.read(keyValueStoreProvider).read(storageKey),
    );
    if (!ref.mounted || generation != _generation) return;
    if (stored == null) return;
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
      'capturedAt': ref
          .read(pendingDeepLinkClockProvider)()
          .toUtc()
          .toIso8601String(),
    });
    await _mutateStorage(
      () => ref.read(keyValueStoreProvider).write(storageKey, record),
    );
    final latestEpoch = await ref.read(accountEpochStoreProvider).current();
    if (!ref.mounted || generation != _generation || latestEpoch != epoch) {
      await _deleteIfUnchanged(record);
      return false;
    }
    return true;
  }

  void consume() {
    _generation += 1;
    state = null;
    unawaited(
      _mutateStorage(() => ref.read(keyValueStoreProvider).delete(storageKey)),
    );
  }

  Future<void> _deleteIfUnchanged(String? expected) {
    if (expected == null) return Future<void>.value();
    return _mutateStorage(() async {
      final store = ref.read(keyValueStoreProvider);
      if (await store.read(storageKey) == expected) {
        await store.delete(storageKey);
      }
    });
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
