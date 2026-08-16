import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/api_providers.dart';
import '../../mission/state/mobile_mission_route.dart';

/// Persists one validated route across the external PKCE/web-activation hop.
class PendingDeepLinkController extends Notifier<String?> {
  static const storageKey = 'leva.mobile.pending_route.v1';
  var _generation = 0;

  @override
  String? build() {
    Future.microtask(restore);
    return null;
  }

  Future<void> restore() async {
    final generation = _generation;
    final stored = await ref.read(keyValueStoreProvider).read(storageKey);
    if (!ref.mounted || generation != _generation) return;
    final route = stored == null ? null : MobileMissionRoute.tryParse(stored);
    if (route == null) {
      state = null;
      if (stored != null) {
        await ref.read(keyValueStoreProvider).delete(storageKey);
      }
      return;
    }
    state = route.location;
  }

  Future<bool> capture(String location) async {
    final route = MobileMissionRoute.tryParse(location);
    if (route == null) return false;
    _generation += 1;
    state = route.location;
    await ref.read(keyValueStoreProvider).write(storageKey, route.location);
    return true;
  }

  void consume() {
    _generation += 1;
    state = null;
    unawaited(ref.read(keyValueStoreProvider).delete(storageKey));
  }
}

final pendingDeepLinkProvider =
    NotifierProvider<PendingDeepLinkController, String?>(
      PendingDeepLinkController.new,
    );
