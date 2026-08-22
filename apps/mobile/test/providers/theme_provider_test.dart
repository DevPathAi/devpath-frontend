import 'dart:async';

import 'package:devpath_mobile/src/providers/theme_provider.dart';
import 'package:devpath_mobile/src/providers/api_providers.dart';
import 'package:devpath_mobile/src/data/key_value_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ProviderContainer _container() {
  final c = ProviderContainer();
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('기본은 system', () {
    expect(_container().read(themeModeProvider), ThemeMode.system);
  });

  test('toggle: system → dark → light → dark', () {
    final c = _container();
    final n = c.read(themeModeProvider.notifier);

    n.toggle();
    expect(c.read(themeModeProvider), ThemeMode.dark);
    n.toggle();
    expect(c.read(themeModeProvider), ThemeMode.light);
    n.toggle();
    expect(c.read(themeModeProvider), ThemeMode.dark);
  });

  test('set: 명시 지정', () {
    final c = _container();
    c.read(themeModeProvider.notifier).set(ThemeMode.light);
    expect(c.read(themeModeProvider), ThemeMode.light);
  });

  test('appearance is restored from durable storage', () async {
    final store = InMemoryKeyValueStore();
    final first = ProviderContainer(
      overrides: [keyValueStoreProvider.overrideWithValue(store)],
    );
    first.read(themeModeProvider.notifier).set(ThemeMode.dark);
    await pumpEventQueue();
    first.dispose();

    final restored = ProviderContainer(
      overrides: [keyValueStoreProvider.overrideWithValue(store)],
    );
    addTearDown(restored.dispose);
    restored.read(themeModeProvider);
    await pumpEventQueue();
    expect(restored.read(themeModeProvider), ThemeMode.dark);
  });

  test('late restore cannot overwrite an explicit user choice', () async {
    final store = _DelayedReadStore('dark');
    final container = ProviderContainer(
      overrides: [keyValueStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(themeModeProvider.notifier);
    await store.readStarted.future;

    notifier.set(ThemeMode.light);
    store.releaseRead.complete();
    await pumpEventQueue();

    expect(container.read(themeModeProvider), ThemeMode.light);
  });

  test('serialized writes persist the newest appearance choice', () async {
    final store = _FirstWriteDelayedStore();
    final container = ProviderContainer(
      overrides: [keyValueStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(themeModeProvider.notifier);

    notifier.set(ThemeMode.dark);
    await store.firstWriteStarted.future;
    notifier.set(ThemeMode.light);
    await pumpEventQueue();
    store.releaseFirstWrite.complete();
    await pumpEventQueue();

    expect(await store.read(ThemeModeController.storageKey), 'light');
  });
}

class _DelayedReadStore implements KeyValueStore {
  _DelayedReadStore(this.value);

  String? value;
  final readStarted = Completer<void>();
  final releaseRead = Completer<void>();

  @override
  Future<String?> read(String key) async {
    final snapshot = value;
    readStarted.complete();
    await releaseRead.future;
    return snapshot;
  }

  @override
  Future<void> write(String key, String value) async => this.value = value;

  @override
  Future<void> delete(String key) async => value = null;
}

class _FirstWriteDelayedStore implements KeyValueStore {
  String? value;
  var writes = 0;
  final firstWriteStarted = Completer<void>();
  final releaseFirstWrite = Completer<void>();

  @override
  Future<String?> read(String key) async => value;

  @override
  Future<void> write(String key, String value) async {
    writes += 1;
    if (writes == 1) {
      firstWriteStarted.complete();
      await releaseFirstWrite.future;
    }
    this.value = value;
  }

  @override
  Future<void> delete(String key) async => value = null;
}
