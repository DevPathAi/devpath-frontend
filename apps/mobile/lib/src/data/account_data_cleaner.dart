import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/today/data/current_mission_cache.dart';
import 'owner_data_store.dart';

/// One explicit account boundary for every durable mobile cache/draft/queue.
/// New owner-scoped stores must be added here before they can ship.
abstract interface class AccountDataCleaner {
  Future<void> clearOwner(String ownerKey);
}

class MobileAccountDataCleaner implements AccountDataCleaner {
  MobileAccountDataCleaner(this._missionCache, this._ownerData);

  final CurrentMissionCache _missionCache;
  final OwnerDataStore _ownerData;

  @override
  Future<void> clearOwner(String ownerKey) async {
    await _missionCache.clearOwner(ownerKey);
    await _ownerData.clearOwner(ownerKey);
  }
}

final accountDataCleanerProvider = Provider<AccountDataCleaner>(
  (ref) => MobileAccountDataCleaner(
    ref.watch(currentMissionCacheProvider),
    ref.watch(ownerDataStoreProvider),
  ),
);
