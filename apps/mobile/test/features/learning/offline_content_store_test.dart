import 'package:devpath_mobile/src/data/owner_data_store.dart';
import 'package:devpath_mobile/src/features/learning/data/content_offline_store.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_test/flutter_test.dart';

const _content = LearningContent(
  id: 77,
  slug: 'async-await',
  title: 'Async',
  track: 'BACKEND',
  markdown: '# Async',
  progress: ContentProgress(scrollPct: 0.1, dwellSec: 5),
);

void main() {
  test('content cache is owner+route keyed and expires at exactly 24h', () async {
    final data = InMemoryOwnerDataStore();
    final cache = ContentOfflineStore(data);
    final cachedAt = DateTime.utc(2026, 8, 15, 12);
    await cache.write('owner-a', '77', _content, cachedAt: cachedAt);

    expect(
      (await cache.read(
        'owner-a',
        '77',
        now: cachedAt.add(const Duration(hours: 23, minutes: 59)),
      ))?.content.id,
      77,
    );
    expect(
      await cache.read(
        'owner-a',
        '77',
        now: cachedAt.add(const Duration(hours: 24)),
      ),
      isNull,
    );
    expect(
      await cache.read('owner-b', '77', now: cachedAt),
      isNull,
    );
  });

  test('progress queue merges monotonically and deduplicates by owner+route', () async {
    final queue = ContentProgressQueue(InMemoryOwnerDataStore());
    await queue.enqueue(
      const QueuedContentProgress(
        ownerKey: 'owner-a',
        routeKey: '77',
        scrollPct: 0.7,
        dwellSec: 20,
        requestCompletion: false,
      ),
    );
    await queue.enqueue(
      const QueuedContentProgress(
        ownerKey: 'owner-a',
        routeKey: '77',
        scrollPct: 0.4,
        dwellSec: 60,
        requestCompletion: true,
      ),
    );

    final pending = await queue.list('owner-a');
    expect(pending, hasLength(1));
    expect(pending.single.scrollPct, 0.7);
    expect(pending.single.dwellSec, 60);
    expect(pending.single.requestCompletion, isTrue);
  });
}
