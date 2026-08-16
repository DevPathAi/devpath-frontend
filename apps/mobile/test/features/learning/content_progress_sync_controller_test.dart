import 'dart:async';

import 'package:devpath_mobile/src/data/owner_data_store.dart';
import 'package:devpath_mobile/src/features/auth/application/auth_controller.dart';
import 'package:devpath_mobile/src/features/learning/application/content_progress_sync_controller.dart';
import 'package:devpath_mobile/src/features/learning/data/content_offline_store.dart';
import 'package:devpath_mobile/src/providers/api_providers.dart';
import 'package:devpath_mobile/src/services/connectivity_service.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('failed progress remains durable then reconnect drains once', () async {
    final fixtures = <String, MockFixture>{};
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
}
