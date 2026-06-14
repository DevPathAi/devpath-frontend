import 'package:devpath_web/src/providers/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('초기값은 system, toggle은 dark→light로 순환한다', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(themeModeProvider), ThemeMode.system);

    final ctrl = container.read(themeModeProvider.notifier);
    ctrl.toggle();
    expect(container.read(themeModeProvider), ThemeMode.dark); // system→dark
    ctrl.toggle();
    expect(container.read(themeModeProvider), ThemeMode.light); // dark→light
    ctrl.toggle();
    expect(container.read(themeModeProvider), ThemeMode.dark); // light→dark
  });
}
