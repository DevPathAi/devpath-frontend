import 'package:devpath_mobile/src/providers/theme_provider.dart';
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
}
