import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'Leva 2.0.0 theme styles primary controls as 30px pointer actions',
    (tester) async {
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
      expect(
        buttonStyle.minimumSize!.resolve({}),
        Size(64, DpDensity.controlHeight),
      );
      expect(buttonStyle.tapTargetSize, MaterialTapTargetSize.shrinkWrap);
      expect(
        (buttonStyle.shape!.resolve({})! as RoundedRectangleBorder)
            .borderRadius,
        BorderRadius.circular(DpRadius.button),
      );
      expect(
        theme.outlinedButtonTheme.style!.minimumSize!.resolve({}),
        Size(64, DpDensity.controlHeight),
      );
      expect(
        theme.textButtonTheme.style!.minimumSize!.resolve({}),
        Size(DpDensity.minTarget, DpDensity.controlHeight),
      );
      expect(
        theme.iconButtonTheme.style!.minimumSize!.resolve({}),
        Size(DpDensity.controlHeight, DpDensity.controlHeight),
      );
      expect(
        theme.iconButtonTheme.style!.tapTargetSize,
        MaterialTapTargetSize.shrinkWrap,
      );
      expect(theme.inputDecorationTheme.filled, isTrue);
      expect(theme.inputDecorationTheme.isDense, isTrue);
      expect(
        theme.inputDecorationTheme.contentPadding,
        const EdgeInsets.symmetric(horizontal: DpSpacing.md, vertical: 5),
      );
      expect(theme.inputDecorationTheme.fillColor, DpColors.light.surfaceMuted);
    },
  );

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
