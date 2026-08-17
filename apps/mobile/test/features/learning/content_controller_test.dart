import 'dart:async';

import 'package:dio/dio.dart';
import 'package:devpath_mobile/src/features/learning/application/content_controller.dart';
import 'package:devpath_mobile/src/features/auth/application/auth_controller.dart';
import 'package:devpath_mobile/src/data/owner_data_store.dart';
import 'package:devpath_mobile/src/features/learning/data/content_offline_store.dart';
import 'package:devpath_mobile/src/features/learning/state/content_state.dart';
import 'package:devpath_mobile/src/providers/api_providers.dart';
import 'package:devpath_mobile/src/services/connectivity_service.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/mock_api.dart';

Map<String, dynamic> _content({
  required bool completed,
  String title = 'Future/async-await 정리',
}) => {
  'id': 1,
  'slug': 'future-async-await',
  'title': title,
  'track': 'BACKEND',
  'markdown': '# 비동기 기초\n본문',
  'estimatedMinutes': 8,
  'conceptTags': <String>[],
  'progress': {
    'scrollPct': 0.2,
    'dwellSec': 12,
    'completed': completed,
    'completedAt': null,
  },
};

final Map<String, MockFixture> _fx = {
  'GET /contents/future-async-await': (200, _content(completed: false)),
  'POST /contents/future-async-await/progress': (
    200,
    {
      'scrollPct': 1.0,
      'dwellSec': 60,
      'completed': true,
      'completedAt': '2026-06-27T10:00:00Z',
    },
  ),
};

ProviderContainer _container(Map<String, MockFixture> fx) {
  final c = ProviderContainer(
    overrides: [
      apiClientProvider.overrideWithValue(mockApiClient(fx)),
      currentOwnerKeyProvider.overrideWithValue(null),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('ContentController', () {
    test('load 성공 → ContentLoaded(마크다운)', () async {
      final c = _container(_fx);
      await c
          .read(contentControllerProvider('future-async-await').notifier)
          .load('future-async-await');
      final s = c.read(contentControllerProvider('future-async-await'));
      expect(s, isA<ContentLoaded>());
      expect((s as ContentLoaded).content.title, 'Future/async-await 정리');
      expect(s.content.progress.completed, isFalse);
    });

    test('markComplete → 진척 completed=true 반영', () async {
      final c = _container(_fx);
      final n = c.read(
        contentControllerProvider('future-async-await').notifier,
      );
      await n.load('future-async-await');
      await n.markComplete('future-async-await');
      final s = c.read(contentControllerProvider('future-async-await'));
      expect(s, isA<ContentLoaded>());
      expect((s as ContentLoaded).content.progress.completed, isTrue);
    });

    test('load 실패 → ContentFailed', () async {
      final c = _container(const {});
      await c.read(contentControllerProvider('missing').notifier).load();
      expect(
        c.read(contentControllerProvider('missing')),
        isA<ContentFailed>(),
      );
    });

    test('reportProgress → 응답 반환 + 진척(completed) 상태 반영', () async {
      final c = _container(_fx);
      final n = c.read(
        contentControllerProvider('future-async-await').notifier,
      );
      await n.load('future-async-await');

      final resp = await n.reportProgress(
        'future-async-await',
        scrollPct: 0.85,
        dwellSec: 50,
      );

      expect(resp, isNotNull);
      expect(resp!.completed, isTrue);
      final s = c.read(contentControllerProvider('future-async-await'));
      expect((s as ContentLoaded).content.progress.completed, isTrue);
    });

    test(
      'reportProgress 실패 → null 반환, 상태는 ContentLoaded 유지(흐름 방해 없음)',
      () async {
        final c = _container({
          'GET /contents/future-async-await': (200, _content(completed: false)),
        });
        final n = c.read(
          contentControllerProvider('future-async-await').notifier,
        );
        await n.load('future-async-await');

        final resp = await n.reportProgress(
          'future-async-await',
          scrollPct: 0.5,
          dwellSec: 30,
        );

        expect(resp, isNull);
        expect(
          c.read(contentControllerProvider('future-async-await')),
          isA<ContentLoaded>(),
        );
      },
    );

    test('malformed progress 응답도 읽던 콘텐츠를 보존한다', () async {
      final c = _container({
        'GET /contents/future-async-await': (200, _content(completed: false)),
        'POST /contents/future-async-await/progress': (
          200,
          <String, dynamic>{'unexpected': true},
        ),
      });
      final n = c.read(
        contentControllerProvider('future-async-await').notifier,
      );
      await n.load('future-async-await');

      final response = await n.reportProgress(
        'future-async-await',
        scrollPct: 0.5,
        dwellSec: 30,
      );

      expect(response, isNull);
      final state = c.read(contentControllerProvider('future-async-await'));
      expect(state, isA<ContentLoaded>());
      expect((state as ContentLoaded).progressFailureMessage, isNotEmpty);
    });

    test(
      'route family isolates content and failed refresh retains route data',
      () async {
        final fixtures = <String, MockFixture>{
          'GET /contents/future-async-await': (200, _content(completed: false)),
        };
        final c = _container(fixtures);
        final first = contentControllerProvider('future-async-await');
        final second = contentControllerProvider('another-route');
        await c.read(first.notifier).load();

        expect(c.read(first), isA<ContentLoaded>());
        expect(c.read(second), isA<ContentLoading>());
        fixtures.clear();
        await c.read(first.notifier).load();
        await c.read(second.notifier).load();

        final retained = c.read(first);
        expect(retained, isA<ContentLoaded>());
        expect((retained as ContentLoaded).isStale, isTrue);
        expect(retained.loadFailureMessage, isNotEmpty);
        expect(c.read(second), isA<ContentFailed>());
      },
    );

    test(
      'offline cache restore merges durable queued progress without local completion',
      () async {
        final data = InMemoryOwnerDataStore();
        final offline = ContentOfflineStore(data);
        final queue = ContentProgressQueue(data);
        final cachedAt = DateTime.now().toUtc();
        await offline.write(
          'owner-a',
          'future-async-await',
          LearningContent.fromJson(_content(completed: false)),
          cachedAt: cachedAt,
        );
        await queue.enqueue(
          const QueuedContentProgress(
            ownerKey: 'owner-a',
            routeKey: 'future-async-await',
            scrollPct: 0.9,
            dwellSec: 80,
            requestCompletion: true,
          ),
        );
        final c = ProviderContainer(
          overrides: [
            apiClientProvider.overrideWithValue(mockApiClient(const {})),
            currentOwnerKeyProvider.overrideWithValue('owner-a'),
            ownerDataStoreProvider.overrideWithValue(data),
            contentOfflineStoreProvider.overrideWithValue(offline),
            contentProgressQueueProvider.overrideWithValue(queue),
            connectivityProvider.overrideWith((_) => const Stream.empty()),
          ],
        );
        addTearDown(c.dispose);
        final provider = contentControllerProvider('future-async-await');

        await c.read(provider.notifier).load();

        final state = c.read(provider) as ContentLoaded;
        expect(state.fromOfflineCache, isTrue);
        expect(state.content.progress.scrollPct, 0.9);
        expect(state.content.progress.dwellSec, 80);
        expect(
          state.content.progress.completed,
          isFalse,
          reason: 'queued completion intent is not server confirmation',
        );
      },
    );

    test('mounted controller drops late A and automatically loads B', () async {
      final api = _QueuedContentApi();
      final data = InMemoryOwnerDataStore();
      final c = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(api),
          currentOwnerKeyProvider.overrideWith(
            (ref) => ref.watch(_contentOwnerProvider),
          ),
          ownerDataStoreProvider.overrideWithValue(data),
          connectivityProvider.overrideWith((_) => const Stream.empty()),
        ],
      );
      addTearDown(c.dispose);
      final provider = contentControllerProvider('future-async-await');
      final subscription = c.listen(provider, (_, _) {});
      addTearDown(subscription.close);

      final aLoad = c.read(provider.notifier).load();
      expect(api.getRequests, hasLength(1));
      c.read(_contentOwnerProvider.notifier).setOwner('owner-b');
      await pumpEventQueue();
      expect(api.getRequests, hasLength(2));
      expect(c.read(provider), isA<ContentLoading>());

      api.getRequests[0].complete(
        _content(completed: false, title: 'A content'),
      );
      await aLoad;
      expect(c.read(provider), isA<ContentLoading>());
      api.getRequests[1].complete(
        _content(completed: false, title: 'B content'),
      );
      await pumpEventQueue();
      expect((c.read(provider) as ContentLoaded).content.title, 'B content');
    });
  });
}

final class _QueuedContentApi extends ApiClient {
  _QueuedContentApi() : super(Dio());

  final getRequests = <Completer<Map<String, dynamic>>>[];

  @override
  Future<T> get<T>(String path, {Map<String, dynamic>? query}) async {
    final request = Completer<Map<String, dynamic>>();
    getRequests.add(request);
    return await request.future as T;
  }
}

final _contentOwnerProvider = NotifierProvider<_ContentOwner, String?>(
  _ContentOwner.new,
);

class _ContentOwner extends Notifier<String?> {
  @override
  String? build() => 'owner-a';

  void setOwner(String? owner) => state = owner;
}
