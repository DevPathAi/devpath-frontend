import 'package:devpath_mobile/src/features/today/data/current_mission_cache.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_test/flutter_test.dart';

CurrentMission _mission(int taskId) {
  final task = <String, Object?>{
    'taskId': taskId,
    'orderNum': 1,
    'taskType': 'READ',
    'title': '오늘의 미션',
    'required': true,
    'contentId': 77,
    'contentSlug': 'today-content',
    'completed': false,
    'completedAt': null,
  };
  return CurrentMission.fromJson({
    'outcome': 'AVAILABLE',
    'pathId': 301,
    'weekNum': 4,
    'tasks': [task],
    'nextTask': task,
    'pathCompleted': false,
  });
}

void main() {
  test('owner별 snapshot은 섞이지 않는다', () async {
    final cache = InMemoryCurrentMissionCache();
    final now = DateTime.utc(2026, 8, 16);
    await cache.write('owner-a', _mission(1), cachedAt: now);
    await cache.write('owner-b', _mission(2), cachedAt: now);

    expect((await cache.read('owner-a', now: now))?.mission.nextTask?.taskId, 1);
    expect((await cache.read('owner-b', now: now))?.mission.nextTask?.taskId, 2);
  });

  test('24시간 미만만 표시하고 정확히 24시간은 만료다', () async {
    final cache = InMemoryCurrentMissionCache();
    final cachedAt = DateTime.utc(2026, 8, 15);
    await cache.write('owner-a', _mission(1), cachedAt: cachedAt);

    expect(
      await cache.read(
        'owner-a',
        now: cachedAt.add(
          const Duration(hours: 24) - const Duration(microseconds: 1),
        ),
      ),
      isNotNull,
    );
    expect(
      await cache.read(
        'owner-a',
        now: cachedAt.add(const Duration(hours: 24)),
      ),
      isNull,
    );
  });

  test('logout cleanup은 해당 owner만 지운다', () async {
    final cache = InMemoryCurrentMissionCache();
    final now = DateTime.utc(2026, 8, 16);
    await cache.write('owner-a', _mission(1), cachedAt: now);
    await cache.write('owner-b', _mission(2), cachedAt: now);

    await cache.clearOwner('owner-a');

    expect(await cache.read('owner-a', now: now), isNull);
    expect(await cache.read('owner-b', now: now), isNotNull);
  });

  test('codec roundtrip은 authoritative outcome과 task pair를 보존한다', () {
    final original = _mission(302);
    final decoded = CurrentMissionCacheCodec.decode(
      CurrentMissionCacheCodec.encode(original),
    );

    expect(decoded.outcome, CurrentMissionOutcome.available);
    expect(decoded.pathId, 301);
    expect(decoded.nextTask?.taskId, 302);
    expect(decoded.nextTask?.contentId, 77);
  });
}
