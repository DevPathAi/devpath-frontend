import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:devpath_mobile/src/data/account_data_cleaner.dart';
import 'package:devpath_mobile/src/data/key_value_store.dart';
import 'package:devpath_mobile/src/data/owner_data_store.dart';
import 'package:devpath_mobile/src/features/auth/application/auth_controller.dart';
import 'package:devpath_mobile/src/features/auth/application/credential_mutation_coordinator.dart';
import 'package:devpath_mobile/src/features/auth/state/auth_state.dart';
import 'package:devpath_mobile/src/features/learning/application/content_progress_sync_controller.dart';
import 'package:devpath_mobile/src/features/learning/data/content_offline_store.dart';
import 'package:devpath_mobile/src/providers/api_providers.dart';
import 'package:devpath_mobile/src/services/connectivity_service.dart';
import 'package:dp_core/dp_core.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('failed progress remains durable then reconnect drains once', () async {
    final fixtures = <String, MockFixture>{
      'POST /contents/77/progress': (
        503,
        {
          'error': {'code': 'UNKNOWN', 'message': 'temporarily unavailable'},
        },
      ),
    };
    final client = ApiClient.create(
      const ApiConfig(baseUrl: 'https://api.example.test'),
    );
    client.dio.httpClientAdapter = MockHttpAdapter(fixtures);
    final data = InMemoryOwnerDataStore();
    final queue = ContentProgressQueue(data);
    final connectivity = StreamController<bool>();
    addTearDown(connectivity.close);
    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(client),
        currentOwnerKeyProvider.overrideWithValue('owner-a'),
        contentProgressQueueProvider.overrideWithValue(queue),
        contentOfflineStoreProvider.overrideWithValue(
          ContentOfflineStore(data),
        ),
        connectivityProvider.overrideWith((_) => connectivity.stream),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      contentProgressSyncControllerProvider,
      (_, _) {},
    );
    addTearDown(subscription.close);
    final controller = container.read(
      contentProgressSyncControllerProvider.notifier,
    );

    final first = await controller.enqueueAndSync(
      const QueuedContentProgress(
        ownerKey: 'owner-a',
        routeKey: '77',
        scrollPct: 0.8,
        dwellSec: 45,
        requestCompletion: true,
      ),
    );
    expect(first, isNull);
    expect(await queue.list('owner-a'), hasLength(1));

    fixtures['POST /contents/77/progress'] = (
      200,
      {
        'scrollPct': 0.8,
        'dwellSec': 45,
        'completed': true,
        'completedAt': '2026-08-16T12:00:00Z',
      },
    );
    connectivity.add(false);
    await pumpEventQueue();
    connectivity.add(true);
    await pumpEventQueue();

    expect(await queue.list('owner-a'), isEmpty);
    expect(container.read(contentProgressSyncControllerProvider), 1);
  });

  test(
    'permanent 404 drops poison row and reconnect does not retry it',
    () async {
      final adapter = _CountingStatusAdapter(404);
      final client = ApiClient.create(
        const ApiConfig(baseUrl: 'https://api.example.test'),
      );
      client.dio.httpClientAdapter = adapter;
      final data = InMemoryOwnerDataStore();
      final queue = ContentProgressQueue(data);
      final connectivity = StreamController<bool>();
      addTearDown(connectivity.close);
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(client),
          currentOwnerKeyProvider.overrideWithValue('owner-a'),
          contentProgressQueueProvider.overrideWithValue(queue),
          contentOfflineStoreProvider.overrideWithValue(
            ContentOfflineStore(data),
          ),
          connectivityProvider.overrideWith((_) => connectivity.stream),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        contentProgressSyncControllerProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);

      await container
          .read(contentProgressSyncControllerProvider.notifier)
          .enqueueAndSync(_progress);
      expect(await queue.list('owner-a'), isEmpty);
      expect(adapter.progressCalls, 1);

      connectivity.add(false);
      await pumpEventQueue();
      connectivity.add(true);
      await pumpEventQueue();
      expect(adapter.progressCalls, 1);
    },
  );

  test(
    'permanent failure discards only the sent row, not a concurrent newer row',
    () async {
      final adapter = _LatchedResponseAdapter(
        status: 404,
        body: {
          'error': {'code': 'RESOURCE_NOT_FOUND', 'message': 'not found'},
        },
      );
      final client = ApiClient.create(
        const ApiConfig(baseUrl: 'https://api.example.test'),
      );
      client.dio.httpClientAdapter = adapter;
      final data = InMemoryOwnerDataStore();
      final queue = ContentProgressQueue(data);
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(client),
          currentOwnerKeyProvider.overrideWithValue('owner-a'),
          contentProgressQueueProvider.overrideWithValue(queue),
          contentOfflineStoreProvider.overrideWithValue(
            ContentOfflineStore(data),
          ),
          connectivityProvider.overrideWith((_) => const Stream.empty()),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        contentProgressSyncControllerProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      final controller = container.read(
        contentProgressSyncControllerProvider.notifier,
      );

      final sent = controller.enqueueAndSync(_progress);
      await adapter.requestStarted.future;
      const newer = QueuedContentProgress(
        ownerKey: 'owner-a',
        routeKey: '77',
        scrollPct: 0.95,
        dwellSec: 120,
        requestCompletion: true,
      );
      await queue.enqueue(newer);
      adapter.releaseResponse.complete();
      await sent;

      final retained = await queue.read('owner-a', '77');
      expect(retained?.scrollPct, newer.scrollPct);
      expect(retained?.dwellSec, newer.dwellSec);
      expect(retained?.requestCompletion, newer.requestCompletion);
    },
  );

  test('malformed 200 retains the durable queue and cached progress', () async {
    final client = ApiClient.create(
      const ApiConfig(baseUrl: 'https://api.example.test'),
    );
    client.dio.httpClientAdapter = MockHttpAdapter({
      'POST /contents/77/progress': (
        200,
        {
          'scrollPct': 2.0,
          'dwellSec': -1,
          'completed': true,
          'completedAt': null,
        },
      ),
    });
    final data = InMemoryOwnerDataStore();
    final queue = ContentProgressQueue(data);
    final cache = ContentOfflineStore(data);
    final cachedAt = DateTime.utc(2026, 8, 16, 1);
    await cache.write(
      'owner-a',
      '77',
      const LearningContent(
        id: 77,
        slug: 'async-await',
        title: 'Safe cached content',
        track: 'BACKEND',
        markdown: '# Safe',
        progress: ContentProgress(scrollPct: 0.4, dwellSec: 40),
      ),
      cachedAt: cachedAt,
    );
    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(client),
        currentOwnerKeyProvider.overrideWithValue('owner-a'),
        contentProgressQueueProvider.overrideWithValue(queue),
        contentOfflineStoreProvider.overrideWithValue(cache),
        connectivityProvider.overrideWith((_) => const Stream.empty()),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      contentProgressSyncControllerProvider,
      (_, _) {},
    );
    addTearDown(subscription.close);

    final response = await container
        .read(contentProgressSyncControllerProvider.notifier)
        .enqueueAndSync(_progress);

    expect(response, isNull);
    expect(await queue.read('owner-a', '77'), isNotNull);
    final retained = await cache.read(
      'owner-a',
      '77',
      now: cachedAt.add(const Duration(minutes: 1)),
    );
    expect(retained?.content.progress.scrollPct, 0.4);
    expect(retained?.content.progress.dwellSec, 40);
  });

  test(
    'progress 401 invalidates auth and clears the exact owner outbox',
    () async {
      final tokens = InMemoryTokenStore();
      final kv = InMemoryKeyValueStore();
      final data = InMemoryOwnerDataStore();
      final cleaner = _StoreCleaner(data);
      await tokens.save(access: 'access', refresh: 'refresh');
      final client = ApiClient.create(
        const ApiConfig(baseUrl: 'https://api.example.test'),
      );
      client.dio.httpClientAdapter = MockHttpAdapter({
        'GET /users/me': (
          200,
          {
            'id': 'owner-a',
            'email': 'a@example.com',
            'nickname': 'A',
            'role': 'LEARNER',
            'onboardingStatus': 'DONE',
            'consentStatus': 'DONE',
          },
        ),
        'POST /contents/77/progress': (
          401,
          {
            'error': {'code': 'UNAUTHORIZED', 'message': 'expired'},
          },
        ),
      });
      final connectivity = StreamController<bool>();
      addTearDown(connectivity.close);
      final queue = ContentProgressQueue(data);
      final container = ProviderContainer(
        overrides: [
          tokenStoreProvider.overrideWithValue(tokens),
          keyValueStoreProvider.overrideWithValue(kv),
          apiClientProvider.overrideWithValue(client),
          accountDataCleanerProvider.overrideWithValue(cleaner),
          ownerDataStoreProvider.overrideWithValue(data),
          contentProgressQueueProvider.overrideWithValue(queue),
          contentOfflineStoreProvider.overrideWithValue(
            ContentOfflineStore(data),
          ),
          connectivityProvider.overrideWith((_) => connectivity.stream),
        ],
      );
      addTearDown(container.dispose);
      final auth = container.read(authControllerProvider.notifier);
      await auth.bootstrapSession();
      expect(container.read(authControllerProvider), isA<AuthAuthenticated>());
      final subscription = container.listen(
        contentProgressSyncControllerProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);

      await container
          .read(contentProgressSyncControllerProvider.notifier)
          .enqueueAndSync(_progress);

      expect(
        container.read(authControllerProvider),
        isA<AuthUnauthenticated>(),
      );
      expect(cleaner.owners, ['owner-a']);
      expect(await tokens.readAccess(), isNull);
      expect(await queue.list('owner-a'), isEmpty);
    },
  );

  test(
    'late A progress 401 cannot invalidate authenticated B or B owner data',
    () async {
      final adapter = _LatchedResponseAdapter(
        status: 401,
        body: {
          'error': {'code': 'UNAUTHORIZED', 'message': 'expired A request'},
        },
      );
      final client = ApiClient.create(
        const ApiConfig(baseUrl: 'https://api.example.test'),
      );
      client.dio.httpClientAdapter = adapter;
      final tokens = InMemoryTokenStore();
      final data = InMemoryOwnerDataStore();
      final queue = ContentProgressQueue(data);
      await tokens.save(access: 'token-a', refresh: 'refresh-a');
      await data.write('owner-b', 'test', 'safe', 'B data');
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(_TrackingAuthController.new),
          tokenStoreProvider.overrideWithValue(tokens),
          ownerDataStoreProvider.overrideWithValue(data),
          apiClientProvider.overrideWithValue(client),
          contentProgressQueueProvider.overrideWithValue(queue),
          contentOfflineStoreProvider.overrideWithValue(
            ContentOfflineStore(data),
          ),
          connectivityProvider.overrideWith((_) => const Stream.empty()),
        ],
      );
      addTearDown(container.dispose);
      final auth =
          container.read(authControllerProvider.notifier)
              as _TrackingAuthController;
      final subscription = container.listen(
        contentProgressSyncControllerProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);

      final syncing = container
          .read(contentProgressSyncControllerProvider.notifier)
          .enqueueAndSync(_progress);
      await adapter.requestStarted.future;
      container.read(credentialMutationCoordinatorProvider).invalidate();
      auth.switchTo(_user('owner-b'));
      await tokens.save(access: 'token-b', refresh: 'refresh-b');
      adapter.releaseResponse.complete();
      await syncing;

      expect(container.read(currentOwnerKeyProvider), 'owner-b');
      expect(container.read(authControllerProvider), isA<AuthAuthenticated>());
      expect(auth.invalidations, 0);
      expect(await tokens.readAccess(), 'token-b');
      expect(await data.read('owner-b', 'test', 'safe'), isNotNull);
      expect(await queue.read('owner-a', '77'), isNotNull);
    },
  );

  test(
    'late progress 401 from an earlier generation cannot invalidate relogin',
    () async {
      final adapter = _LatchedResponseAdapter(
        status: 401,
        body: {
          'error': {'code': 'UNAUTHORIZED', 'message': 'expired old session'},
        },
      );
      final client = ApiClient.create(
        const ApiConfig(baseUrl: 'https://api.example.test'),
      );
      client.dio.httpClientAdapter = adapter;
      final tokens = InMemoryTokenStore();
      final data = InMemoryOwnerDataStore();
      final queue = ContentProgressQueue(data);
      await tokens.save(access: 'old-token', refresh: 'old-refresh');
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(_TrackingAuthController.new),
          tokenStoreProvider.overrideWithValue(tokens),
          ownerDataStoreProvider.overrideWithValue(data),
          apiClientProvider.overrideWithValue(client),
          contentProgressQueueProvider.overrideWithValue(queue),
          contentOfflineStoreProvider.overrideWithValue(
            ContentOfflineStore(data),
          ),
          connectivityProvider.overrideWith((_) => const Stream.empty()),
        ],
      );
      addTearDown(container.dispose);
      final auth =
          container.read(authControllerProvider.notifier)
              as _TrackingAuthController;
      final subscription = container.listen(
        contentProgressSyncControllerProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);

      final syncing = container
          .read(contentProgressSyncControllerProvider.notifier)
          .enqueueAndSync(_progress);
      await adapter.requestStarted.future;
      container.read(credentialMutationCoordinatorProvider).invalidate();
      auth.switchTo(_user('owner-a', nickname: 'new A session'));
      await tokens.save(access: 'new-token', refresh: 'new-refresh');
      adapter.releaseResponse.complete();
      await syncing;

      expect(container.read(currentOwnerKeyProvider), 'owner-a');
      expect(container.read(authControllerProvider), isA<AuthAuthenticated>());
      expect(auth.invalidations, 0);
      expect(await tokens.readAccess(), 'new-token');
      expect(await queue.read('owner-a', '77'), isNotNull);
    },
  );

  test(
    'success mutation cannot overwrite same-owner content after epoch clear',
    () async {
      final client = ApiClient.create(
        const ApiConfig(baseUrl: 'https://api.example.test'),
      );
      client.dio.httpClientAdapter = MockHttpAdapter({
        'POST /contents/77/progress': (
          200,
          {
            'scrollPct': 0.8,
            'dwellSec': 45,
            'completed': false,
            'completedAt': null,
          },
        ),
      });
      final data = InMemoryOwnerDataStore();
      final queue = ContentProgressQueue(data);
      final cache = _LatchedApplyContentStore(data);
      final oldCachedAt = DateTime.utc(2026, 8, 16, 1);
      await cache.write(
        'owner-a',
        '77',
        _content(title: 'old A content', scrollPct: 0.2),
        cachedAt: oldCachedAt,
      );
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(client),
          currentOwnerKeyProvider.overrideWithValue('owner-a'),
          contentProgressQueueProvider.overrideWithValue(queue),
          contentOfflineStoreProvider.overrideWithValue(cache),
          connectivityProvider.overrideWith((_) => const Stream.empty()),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        contentProgressSyncControllerProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);

      final syncing = container
          .read(contentProgressSyncControllerProvider.notifier)
          .enqueueAndSync(_progress);
      await cache.applyStarted.future;
      final mutations = container.read(credentialMutationCoordinatorProvider);
      mutations.invalidate();
      final replacement = mutations.run(() async {
        await data.clearOwner('owner-a');
        await ContentOfflineStore(data).write(
          'owner-a',
          '77',
          _content(title: 'new A session content', scrollPct: 0.1),
          cachedAt: oldCachedAt.add(const Duration(hours: 1)),
        );
        await queue.enqueue(
          const QueuedContentProgress(
            ownerKey: 'owner-a',
            routeKey: '77',
            scrollPct: 0.1,
            dwellSec: 5,
            requestCompletion: false,
          ),
        );
      });
      await pumpEventQueue();
      cache.releaseApply.complete();
      await Future.wait<void>([syncing, replacement]);

      final retained = await cache.read(
        'owner-a',
        '77',
        now: oldCachedAt.add(const Duration(hours: 2)),
      );
      expect(retained?.content.title, 'new A session content');
      expect(retained?.content.progress.scrollPct, 0.1);
      expect(retained?.content.progress.dwellSec, 5);
      expect((await queue.read('owner-a', '77'))?.scrollPct, 0.1);
    },
  );

  test(
    'late 401 remove cannot delete same-owner queue after epoch clear',
    () async {
      final client = ApiClient.create(
        const ApiConfig(baseUrl: 'https://api.example.test'),
      );
      client.dio.httpClientAdapter = MockHttpAdapter({
        'POST /contents/77/progress': (
          401,
          {
            'error': {'code': 'UNAUTHORIZED', 'message': 'old session'},
          },
        ),
      });
      final data = InMemoryOwnerDataStore();
      final queue = _LatchedRemoveQueue(data);
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(client),
          currentOwnerKeyProvider.overrideWithValue('owner-a'),
          contentProgressQueueProvider.overrideWithValue(queue),
          contentOfflineStoreProvider.overrideWithValue(
            ContentOfflineStore(data),
          ),
          connectivityProvider.overrideWith((_) => const Stream.empty()),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        contentProgressSyncControllerProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);

      final syncing = container
          .read(contentProgressSyncControllerProvider.notifier)
          .enqueueAndSync(_progress);
      await queue.removeStarted.future;
      final mutations = container.read(credentialMutationCoordinatorProvider);
      mutations.invalidate();
      final replacement = mutations.run(() async {
        await data.clearOwner('owner-a');
        await queue.enqueue(
          const QueuedContentProgress(
            ownerKey: 'owner-a',
            routeKey: '77',
            scrollPct: 0.95,
            dwellSec: 120,
            requestCompletion: true,
          ),
        );
      });
      await pumpEventQueue();
      queue.releaseRemove.complete();
      await Future.wait<void>([syncing, replacement]);

      final retained = await queue.read('owner-a', '77');
      expect(retained?.scrollPct, 0.95);
      expect(retained?.dwellSec, 120);
      expect(retained?.requestCompletion, isTrue);
    },
  );

  test(
    'enqueue at empty-read flight tail drains without external reconnect',
    () async {
      final client = ApiClient.create(
        const ApiConfig(baseUrl: 'https://api.example.test'),
      );
      client.dio.httpClientAdapter = MockHttpAdapter({
        'POST /contents/77/progress': (
          200,
          {
            'scrollPct': 0.8,
            'dwellSec': 45,
            'completed': false,
            'completedAt': null,
          },
        ),
      });
      final data = InMemoryOwnerDataStore();
      final queue = _FlightTailQueue();
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(client),
          currentOwnerKeyProvider.overrideWithValue('owner-a'),
          contentProgressQueueProvider.overrideWithValue(queue),
          contentOfflineStoreProvider.overrideWithValue(
            ContentOfflineStore(data),
          ),
          connectivityProvider.overrideWith((_) => const Stream.empty()),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        contentProgressSyncControllerProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      final controller = container.read(
        contentProgressSyncControllerProvider.notifier,
      );
      late Future<ContentProgressUpdateResponse?> enqueued;
      queue.onFirstEmpty = () {
        enqueued = controller.enqueueAndSync(_progress);
      };

      await controller.syncRoute('owner-a', '77');
      await enqueued;

      expect(await queue.read('owner-a', '77'), isNull);
      expect(queue.acknowledgements, 1);
    },
  );
}

const _progress = QueuedContentProgress(
  ownerKey: 'owner-a',
  routeKey: '77',
  scrollPct: 0.8,
  dwellSec: 45,
  requestCompletion: true,
);

LearningContent _content({required String title, required double scrollPct}) =>
    LearningContent(
      id: 77,
      slug: '77',
      title: title,
      track: 'BACKEND',
      markdown: '# $title',
      progress: ContentProgress(scrollPct: scrollPct, dwellSec: 5),
    );

class _StoreCleaner implements AccountDataCleaner {
  _StoreCleaner(this.data);

  final OwnerDataStore data;
  final owners = <String>[];

  @override
  Future<void> clearOwner(String ownerKey) async {
    owners.add(ownerKey);
    await data.clearOwner(ownerKey);
  }
}

final class _TrackingAuthController extends AuthController {
  var invalidations = 0;

  @override
  AuthState build() => AuthAuthenticated(_user('owner-a'));

  void switchTo(User user) => state = AuthAuthenticated(user);

  @override
  Future<void> invalidateUnauthorized([String? message]) async {
    invalidations += 1;
    final ownerKey = state.ownerKey;
    await ref.read(tokenStoreProvider).clear();
    if (ownerKey != null) {
      await ref.read(ownerDataStoreProvider).clearOwner(ownerKey);
    }
    state = AuthUnauthenticated(error: message);
  }
}

User _user(String id, {String? nickname}) => User(
  id: id,
  email: '$id@example.com',
  nickname: nickname ?? id,
  role: UserRole.learner,
  onboardingStatus: OnboardingStatus.done,
  consentStatus: ConsentStatus.done,
);

class _CountingStatusAdapter implements HttpClientAdapter {
  _CountingStatusAdapter(this.status);

  final int status;
  var progressCalls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path == '/contents/77/progress') progressCalls += 1;
    return ResponseBody.fromString(
      jsonEncode({
        'error': {'code': 'RESOURCE_NOT_FOUND', 'message': 'not found'},
      }),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _LatchedResponseAdapter implements HttpClientAdapter {
  _LatchedResponseAdapter({required this.status, required this.body});

  final int status;
  final Map<String, dynamic> body;
  final requestStarted = Completer<void>();
  final releaseResponse = Completer<void>();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (!requestStarted.isCompleted) requestStarted.complete();
    await releaseResponse.future;
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _LatchedApplyContentStore extends ContentOfflineStore {
  _LatchedApplyContentStore(super.data);

  final applyStarted = Completer<void>();
  final releaseApply = Completer<void>();

  @override
  Future<void> applyServerProgress(
    String ownerKey,
    String routeKey,
    ContentProgressUpdateResponse response,
  ) async {
    applyStarted.complete();
    await releaseApply.future;
    await super.applyServerProgress(ownerKey, routeKey, response);
  }
}

class _LatchedRemoveQueue extends ContentProgressQueue {
  _LatchedRemoveQueue(super.data);

  final removeStarted = Completer<void>();
  final releaseRemove = Completer<void>();

  @override
  Future<void> remove(String ownerKey, String routeKey) async {
    removeStarted.complete();
    await releaseRemove.future;
    await super.remove(ownerKey, routeKey);
  }
}

class _FlightTailQueue extends ContentProgressQueue {
  _FlightTailQueue() : super(InMemoryOwnerDataStore());

  void Function()? onFirstEmpty;
  QueuedContentProgress? _pending;
  var _didSignalEmpty = false;
  var acknowledgements = 0;

  @override
  Future<QueuedContentProgress?> read(String ownerKey, String routeKey) async {
    final value = _pending;
    if (value == null && !_didSignalEmpty) {
      _didSignalEmpty = true;
      onFirstEmpty?.call();
    }
    return value;
  }

  @override
  Future<QueuedContentProgress> enqueue(QueuedContentProgress incoming) async {
    _pending = incoming;
    return incoming;
  }

  @override
  Future<bool> acknowledge(QueuedContentProgress sent) async {
    if (_pending != sent) return false;
    _pending = null;
    acknowledgements += 1;
    return true;
  }

  @override
  Future<List<QueuedContentProgress>> list(String ownerKey) async => [
    ?_pending,
  ];

  @override
  Future<void> remove(String ownerKey, String routeKey) async {
    _pending = null;
  }
}
