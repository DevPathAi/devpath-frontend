import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/today/data/current_mission_cache.dart';

/// One explicit account boundary for every durable mobile cache/draft/queue.
/// New owner-scoped stores must be added here before they can ship.
abstract interface class AccountDataCleaner {
  Future<void> clearOwner(String ownerKey);
}

class MobileAccountDataCleaner implements AccountDataCleaner {
  MobileAccountDataCleaner(this._missionCache);

  final CurrentMissionCache _missionCache;

  @override
  Future<void> clearOwner(String ownerKey) =>
      _missionCache.clearOwner(ownerKey);
}

final accountDataCleanerProvider = Provider<AccountDataCleaner>(
  (ref) => MobileAccountDataCleaner(ref.watch(currentMissionCacheProvider)),
);
