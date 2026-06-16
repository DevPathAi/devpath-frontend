import 'package:devpath_web/src/app/app.dart';
import 'package:devpath_web/src/providers/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('themeMode 토글이 MaterialApp에 반영된다', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const DevPathWebApp(),
      ),
    );
    await tester.pumpAndSettle();

    MaterialApp app() => tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app().themeMode, ThemeMode.system);

    container.read(themeModeProvider.notifier).toggle();
    await tester.pumpAndSettle();
    expect(app().themeMode, ThemeMode.dark);
  });
}
