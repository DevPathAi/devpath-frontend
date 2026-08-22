import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_providers.dart';

/// 라이트/다크 테마 토글. 기본 system, 토글 시 dark↔light(web theme_provider와 동일 정책).
class ThemeModeController extends Notifier<ThemeMode> {
  static const storageKey = 'leva.mobile.appearance.v1';
  var _generation = 0;
  Future<void> _persistenceTail = Future<void>.value();

  @override
  ThemeMode build() {
    Future.microtask(_restore);
    return ThemeMode.system;
  }

  Future<void> _restore() async {
    final generation = _generation;
    try {
      final saved = await ref.read(keyValueStoreProvider).read(storageKey);
      if (!ref.mounted || generation != _generation) return;
      state = switch (saved) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
    } on Object {
      // Appearance persistence is best-effort and never blocks app startup.
    }
  }

  void toggle() {
    set(switch (state) {
      ThemeMode.dark => ThemeMode.light,
      _ => ThemeMode.dark, // system/light → dark
    });
  }

  void set(ThemeMode mode) {
    _generation += 1;
    state = mode;
    final store = ref.read(keyValueStoreProvider);
    final operation = _persistenceTail.then(
      (_) => store.write(storageKey, mode.name),
    );
    _persistenceTail = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    unawaited(_persistenceTail);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);
