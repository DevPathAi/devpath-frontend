import 'package:devpath_mobile/src/data/account_data_cleaner.dart';
import 'package:devpath_mobile/src/data/owner_data_store.dart';
import 'package:devpath_mobile/src/features/today/data/current_mission_cache.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('owner-data cleanup still runs when mission cleanup fails', () async {
    final missionError = StateError('mission cleanup failed');
    final mission = _RecordingMissionCache(error: missionError);
    final ownerData = _RecordingOwnerDataStore();
    final cleaner = MobileAccountDataCleaner(mission, ownerData);

    await expectLater(
      cleaner.clearOwner('owner-a'),
      throwsA(same(missionError)),
    );

    expect(mission.owners, ['owner-a']);
    expect(ownerData.owners, ['owner-a']);
  });

  test(
    'mission cleanup is attempted before an owner-data failure is reported',
    () async {
      final ownerError = StateError('owner cleanup failed');
      final mission = _RecordingMissionCache();
      final ownerData = _RecordingOwnerDataStore(error: ownerError);
      final cleaner = MobileAccountDataCleaner(mission, ownerData);

      await expectLater(
        cleaner.clearOwner('owner-b'),
        throwsA(same(ownerError)),
      );

      expect(mission.owners, ['owner-b']);
      expect(ownerData.owners, ['owner-b']);
    },
  );
}

class _RecordingMissionCache extends InMemoryCurrentMissionCache {
  _RecordingMissionCache({this.error});

  final Object? error;
  final List<String> owners = [];

  @override
  Future<void> clearOwner(String ownerKey) async {
    owners.add(ownerKey);
    if (error != null) throw error!;
    await super.clearOwner(ownerKey);
  }
}

class _RecordingOwnerDataStore extends InMemoryOwnerDataStore {
  _RecordingOwnerDataStore({this.error});

  final Object? error;
  final List<String> owners = [];

  @override
  Future<void> clearOwner(String ownerKey) async {
    owners.add(ownerKey);
    if (error != null) throw error!;
    await super.clearOwner(ownerKey);
  }
}
