import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Leva v2 theme styles primary controls as 52px product actions', (
    tester,
  ) async {
    late ThemeData theme;
    await tester.pumpWidget(
      MaterialApp(
        theme: DpTheme.light(),
        home: Builder(
          builder: (context) {
            theme = Theme.of(context);
            return const SizedBox();
          },
        ),
      ),
    );

    final buttonStyle = theme.filledButtonTheme.style!;
    expect(buttonStyle.minimumSize!.resolve({}), const Size(64, 52));
    expect(
      (buttonStyle.shape!.resolve({})! as RoundedRectangleBorder).borderRadius,
      BorderRadius.circular(DpRadius.button),
    );
    expect(theme.inputDecorationTheme.filled, isTrue);
    expect(theme.inputDecorationTheme.fillColor, DpColors.light.surfaceMuted);
  });

  testWidgets('Leva v2 theme owns cards, sheets, chips and floating actions', (
    tester,
  ) async {
    late ThemeData theme;
    await tester.pumpWidget(
      MaterialApp(
        theme: DpTheme.light(),
        home: Builder(
          builder: (context) {
            theme = Theme.of(context);
            return const SizedBox();
          },
        ),
      ),
    );

    expect(theme.cardTheme.color, DpColors.light.surface);
    expect(theme.cardTheme.elevation, 0);
    expect(theme.bottomSheetTheme.backgroundColor, DpColors.light.surface);
    expect(theme.chipTheme.shape, isA<RoundedRectangleBorder>());
    expect(theme.floatingActionButtonTheme.elevation, 0);
  });
}
