import 'dart:async';

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
  test(
    'content cache is owner+route keyed and expires at exactly 24h',
    () async {
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
      expect(await cache.read('owner-b', '77', now: cachedAt), isNull);
    },
  );

  test(
    'progress queue merges monotonically and deduplicates by owner+route',
    () async {
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
    },
  );

  test(
    'concurrent progress enqueues cannot lose either monotonic maximum',
    () async {
      final queue = ContentProgressQueue(InMemoryOwnerDataStore());

      await Future.wait([
        queue.enqueue(
          const QueuedContentProgress(
            ownerKey: 'owner-a',
            routeKey: '77',
            scrollPct: 0.9,
            dwellSec: 1,
            requestCompletion: false,
          ),
        ),
        queue.enqueue(
          const QueuedContentProgress(
            ownerKey: 'owner-a',
            routeKey: '77',
            scrollPct: 0.1,
            dwellSec: 100,
            requestCompletion: true,
          ),
        ),
      ]);

      final pending = await queue.read('owner-a', '77');
      expect(pending?.scrollPct, 0.9);
      expect(pending?.dwellSec, 100);
      expect(pending?.requestCompletion, isTrue);
    },
  );

  test(
    'progress merge cannot overwrite a concurrent authoritative content write',
    () async {
      final data = _LatchedSnapshotStore();
      final cache = ContentOfflineStore(data);
      final oldAt = DateTime.utc(2026, 8, 16, 1);
      final newAt = DateTime.utc(2026, 8, 16, 2);
      await cache.write('owner-a', '77', _content, cachedAt: oldAt);
      data.latchNextRead = true;

      final applying = cache.applyServerProgress(
        'owner-a',
        '77',
        const ContentProgressUpdateResponse(
          scrollPct: 0.8,
          dwellSec: 80,
          completed: false,
        ),
      );
      await data.snapshotCaptured.future;
      const authoritative = LearningContent(
        id: 77,
        slug: 'async-await',
        title: 'Authoritative title',
        track: 'BACKEND',
        markdown: '# Fresh server body',
        progress: ContentProgress(scrollPct: 0.4, dwellSec: 40),
      );
      final writing = cache.write(
        'owner-a',
        '77',
        authoritative,
        cachedAt: newAt,
      );
      await pumpEventQueue();
      data.releaseSnapshot.complete();
      await Future.wait([applying, writing]);

      final saved = await cache.read(
        'owner-a',
        '77',
        now: newAt.add(const Duration(minutes: 1)),
      );
      expect(saved?.content.title, authoritative.title);
      expect(saved?.content.markdown, authoritative.markdown);
      expect(saved?.cachedAt, newAt);
    },
  );
}

class _LatchedSnapshotStore extends InMemoryOwnerDataStore {
  var latchNextRead = false;
  final snapshotCaptured = Completer<void>();
  final releaseSnapshot = Completer<void>();

  @override
  Future<OwnerDataRecord?> read(
    String ownerKey,
    String bucket,
    String recordKey,
  ) async {
    final snapshot = await super.read(ownerKey, bucket, recordKey);
    if (latchNextRead) {
      latchNextRead = false;
      snapshotCaptured.complete();
      await releaseSnapshot.future;
    }
    return snapshot;
  }
}
