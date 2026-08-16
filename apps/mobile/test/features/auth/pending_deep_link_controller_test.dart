import 'dart:async';

import 'package:devpath_mobile/src/data/key_value_store.dart';
import 'package:devpath_mobile/src/features/auth/application/pending_deep_link_controller.dart';
import 'package:devpath_mobile/src/features/auth/application/account_epoch_store.dart';
import 'package:devpath_mobile/src/providers/api_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ProviderContainer _container(
  KeyValueStore store, {
  DateTime Function()? clock,
}) => ProviderContainer(
  overrides: [
    keyValueStoreProvider.overrideWithValue(store),
    if (clock != null) pendingDeepLinkClockProvider.overrideWithValue(clock),
  ],
);

void main() {
  test('canonical route는 외부 로그인/activation을 건너 앱 재생성 뒤 복구된다', () async {
    final store = InMemoryKeyValueStore();
    final first = _container(store);
    await first
        .read(pendingDeepLinkProvider.notifier)
        .capture('/mission/302/content/77');
    first.dispose();

    final restored = _container(store);
    addTearDown(restored.dispose);
    await restored.read(pendingDeepLinkProvider.notifier).restore();

    expect(restored.read(pendingDeepLinkProvider), '/mission/302/content/77');
  });

  test('serialized pending route expires at TTL equality', () async {
    final store = InMemoryKeyValueStore();
    final capturedAt = DateTime.utc(2026, 8, 16, 12);
    final first = _container(store, clock: () => capturedAt);
    await first
        .read(pendingDeepLinkProvider.notifier)
        .capture('/path/301/today');
    final raw = await store.read(PendingDeepLinkController.storageKey);
    expect(raw, contains('"ownerEpoch":0'));
    expect(raw, contains('"generation":1'));
    first.dispose();

    final expired = _container(
      store,
      clock: () => capturedAt.add(PendingDeepLinkController.ttl),
    );
    addTearDown(expired.dispose);
    await expired.read(pendingDeepLinkProvider.notifier).restore();
    expect(expired.read(pendingDeepLinkProvider), isNull);
    expect(await store.read(PendingDeepLinkController.storageKey), isNull);
  });

  test('account epoch advance invalidates an older pending route', () async {
    final store = InMemoryKeyValueStore();
    final now = DateTime.utc(2026, 8, 16, 12);
    final first = _container(store, clock: () => now);
    await first
        .read(pendingDeepLinkProvider.notifier)
        .capture('/mission/302/content/77');
    first.dispose();
    await AccountEpochStore(store).advance();

    final next = _container(store, clock: () => now);
    addTearDown(next.dispose);
    await next.read(pendingDeepLinkProvider.notifier).restore();
    expect(next.read(pendingDeepLinkProvider), isNull);
  });

  test('허용되지 않은 native route는 저장하지 않고 consume은 durable 값을 지운다', () async {
    final store = InMemoryKeyValueStore();
    final container = _container(store);
    addTearDown(container.dispose);
    final controller = container.read(pendingDeepLinkProvider.notifier);

    expect(await controller.capture('/review'), isFalse);
    expect(container.read(pendingDeepLinkProvider), isNull);

    await controller.capture('/path/301/today');
    controller.consume();
    await Future<void>.delayed(Duration.zero);

    expect(container.read(pendingDeepLinkProvider), isNull);
    expect(await store.read(PendingDeepLinkController.storageKey), isNull);
  });

  test('consume의 늦은 삭제는 더 새 generation의 route를 지우지 않는다', () async {
    final store = _DelayedDeleteStore();
    final container = _container(store);
    addTearDown(container.dispose);
    final controller = container.read(pendingDeepLinkProvider.notifier);
    await controller.capture('/path/301/today');

    controller.consume();
    await store.deleteStarted.future;
    final newerCapture = controller.capture('/mission/302/content/77');
    await Future<void>.delayed(Duration.zero);
    store.releaseDelete.complete();
    expect(await newerCapture, isTrue);

    expect(
      await store.read(PendingDeepLinkController.storageKey),
      contains('/mission/302/content/77'),
    );
  });

  test('scheduled consume CAS preserves a newer captured route', () async {
    final store = InMemoryKeyValueStore();
    final container = _container(store);
    addTearDown(container.dispose);
    final controller = container.read(pendingDeepLinkProvider.notifier);
    await controller.capture('/path/301/today');
    final scheduledGeneration = controller.generation;

    await controller.capture('/mission/302/content/77');
    controller.consumeIfMatches(
      '/path/301/today',
      expectedGeneration: scheduledGeneration,
    );
    await pumpEventQueue();

    expect(container.read(pendingDeepLinkProvider), '/mission/302/content/77');
    expect(
      await store.read(PendingDeepLinkController.storageKey),
      contains('/mission/302/content/77'),
    );
  });
}

class _DelayedDeleteStore implements KeyValueStore {
  final _delegate = InMemoryKeyValueStore();
  final deleteStarted = Completer<void>();
  final releaseDelete = Completer<void>();
  var _delayed = false;

  @override
  Future<String?> read(String key) => _delegate.read(key);

  @override
  Future<void> write(String key, String value) => _delegate.write(key, value);

  @override
  Future<void> delete(String key) async {
    if (!_delayed && key == PendingDeepLinkController.storageKey) {
      _delayed = true;
      deleteStarted.complete();
      await releaseDelete.future;
    }
    await _delegate.delete(key);
  }
}
