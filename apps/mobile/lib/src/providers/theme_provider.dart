import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_providers.dart';

/// 라이트/다크 테마 토글. 기본 system, 토글 시 dark↔light(web theme_provider와 동일 정책).
class ThemeModeController extends Notifier<ThemeMode> {
  static const storageKey = 'leva.mobile.appearance.v1';

  @override
  ThemeMode build() {
    Future.microtask(_restore);
    return ThemeMode.system;
  }

  Future<void> _restore() async {
    try {
      final saved = await ref.read(keyValueStoreProvider).read(storageKey);
      if (!ref.mounted) return;
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
    state = mode;
    unawaited(
      ref
          .read(keyValueStoreProvider)
          .write(storageKey, mode.name)
          .catchError((_) {}),
    );
  }
}

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);
