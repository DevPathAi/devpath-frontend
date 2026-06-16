import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 전역 라이트/다크 토글(DD6). 기본 system, 토글 시 dark↔light.
class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.system;

  void toggle() {
    state = switch (state) {
      ThemeMode.dark => ThemeMode.light,
      _ => ThemeMode.dark, // system/light → dark
    };
  }

  void set(ThemeMode mode) => state = mode;
}

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);
