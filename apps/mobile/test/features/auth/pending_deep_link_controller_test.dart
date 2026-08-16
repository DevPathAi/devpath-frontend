import 'package:devpath_mobile/src/data/key_value_store.dart';
import 'package:devpath_mobile/src/features/auth/application/pending_deep_link_controller.dart';
import 'package:devpath_mobile/src/providers/api_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ProviderContainer _container(KeyValueStore store) => ProviderContainer(
  overrides: [keyValueStoreProvider.overrideWithValue(store)],
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
}
