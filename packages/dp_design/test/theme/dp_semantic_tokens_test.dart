import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DpSemanticTokenManifest v1', () {
    test('manifest schema/version and CSS names are stable and unique', () {
      expect(DpSemanticTokenManifest.schema, 'leva.semantic-tokens');
      expect(DpSemanticTokenManifest.version, '1.0.0');

      final tokens = DpSemanticTokenManifest.tokens;
      expect(tokens, isNotEmpty);
      expect(
        tokens.map((token) => token.flutterName).toSet().length,
        tokens.length,
      );
      expect(
        tokens.map((token) => token.cssCustomProperty).toSet().length,
        tokens.length,
      );
      for (final token in tokens) {
        expect(token.cssCustomProperty, startsWith('--dp-'));
        expect(token.allowedUsages, isNotEmpty, reason: token.flutterName);
      }
    });

    test('all current DpColors fields map to exact light/dark values', () {
      final expected = <DpSemanticColorRole, (Color, Color)>{
        DpSemanticColorRole.primary: (
          DpColors.light.primary,
          DpColors.dark.primary,
        ),
        DpSemanticColorRole.primaryText: (
          DpColors.light.primaryText,
          DpColors.dark.primaryText,
        ),
        DpSemanticColorRole.primaryTextStrong: (
          DpColors.light.primaryTextStrong,
          DpColors.dark.primaryTextStrong,
        ),
        DpSemanticColorRole.onPrimary: (
          DpColors.light.onPrimary,
          DpColors.dark.onPrimary,
        ),
        DpSemanticColorRole.accentSoft: (
          DpColors.light.accentSoft,
          DpColors.dark.accentSoft,
        ),
        DpSemanticColorRole.accentLine: (
          DpColors.light.accentLine,
          DpColors.dark.accentLine,
        ),
        DpSemanticColorRole.bg: (DpColors.light.bg, DpColors.dark.bg),
        DpSemanticColorRole.surface: (
          DpColors.light.surface,
          DpColors.dark.surface,
        ),
        DpSemanticColorRole.surfaceMuted: (
          DpColors.light.surfaceMuted,
          DpColors.dark.surfaceMuted,
        ),
        DpSemanticColorRole.border: (
          DpColors.light.border,
          DpColors.dark.border,
        ),
        DpSemanticColorRole.textPrimary: (
          DpColors.light.textPrimary,
          DpColors.dark.textPrimary,
        ),
        DpSemanticColorRole.textSecondary: (
          DpColors.light.textSecondary,
          DpColors.dark.textSecondary,
        ),
        DpSemanticColorRole.textFaint: (
          DpColors.light.textFaint,
          DpColors.dark.textFaint,
        ),
        DpSemanticColorRole.railBg: (
          DpColors.light.railBg,
          DpColors.dark.railBg,
        ),
        DpSemanticColorRole.railText: (
          DpColors.light.railText,
          DpColors.dark.railText,
        ),
        DpSemanticColorRole.railMuted: (
          DpColors.light.railMuted,
          DpColors.dark.railMuted,
        ),
        DpSemanticColorRole.railFaint: (
          DpColors.light.railFaint,
          DpColors.dark.railFaint,
        ),
        DpSemanticColorRole.railActive: (
          DpColors.light.railActive,
          DpColors.dark.railActive,
        ),
        DpSemanticColorRole.railBorder: (
          DpColors.light.railBorder,
          DpColors.dark.railBorder,
        ),
        DpSemanticColorRole.success: (
          DpColors.light.success,
          DpColors.dark.success,
        ),
        DpSemanticColorRole.warning: (
          DpColors.light.warning,
          DpColors.dark.warning,
        ),
        DpSemanticColorRole.danger: (
          DpColors.light.danger,
          DpColors.dark.danger,
        ),
        DpSemanticColorRole.tagBg: (DpColors.light.tagBg, DpColors.dark.tagBg),
        DpSemanticColorRole.tagText: (
          DpColors.light.tagText,
          DpColors.dark.tagText,
        ),
        DpSemanticColorRole.chart1: (
          DpColors.light.chart1,
          DpColors.dark.chart1,
        ),
        DpSemanticColorRole.chart2: (
          DpColors.light.chart2,
          DpColors.dark.chart2,
        ),
        DpSemanticColorRole.chart3: (
          DpColors.light.chart3,
          DpColors.dark.chart3,
        ),
        DpSemanticColorRole.chart4: (
          DpColors.light.chart4,
          DpColors.dark.chart4,
        ),
        DpSemanticColorRole.chart5: (
          DpColors.light.chart5,
          DpColors.dark.chart5,
        ),
        DpSemanticColorRole.codeEditorBg: (
          DpColors.light.codeEditorBg,
          DpColors.dark.codeEditorBg,
        ),
        DpSemanticColorRole.codeLogBg: (
          DpColors.light.codeLogBg,
          DpColors.dark.codeLogBg,
        ),
        DpSemanticColorRole.codeText: (
          DpColors.light.codeText,
          DpColors.dark.codeText,
        ),
      };

      expect(DpSemanticTokenManifest.colors.length, expected.length);
      for (final token in DpSemanticTokenManifest.colors) {
        final values = expected[token.role]!;
        expect(token.lightValue, values.$1, reason: token.flutterName);
        expect(token.darkValue, values.$2, reason: token.flutterName);
        expect(
          token.valueFor(Brightness.light),
          token.role.resolve(DpColors.light),
        );
        expect(
          token.valueFor(Brightness.dark),
          token.role.resolve(DpColors.dark),
        );
      }
    });

    test(
      'spacing, radius, duration and typography values stay source-mapped',
      () {
        expect(
          DpSemanticTokenManifest.spacing
              .map((token) => token.lightValue)
              .toList(),
          [
            DpSpacing.xs,
            DpSpacing.sm,
            DpSpacing.md,
            DpSpacing.lg,
            DpSpacing.xl,
            DpSpacing.xxl,
            DpSpacing.xxxl,
          ],
        );
        expect(
          DpSemanticTokenManifest.radii
              .firstWhere(
                (token) => token.cssCustomProperty == '--dp-radius-panel',
              )
              .lightValue,
          DpRadius.card,
        );
        expect(
          DpSemanticTokenManifest.durations
              .firstWhere(
                (token) => token.cssCustomProperty == '--dp-duration-select',
              )
              .lightValue,
          DpDurations.select,
        );

        final reading = DpSemanticTokenManifest.typography.firstWhere(
          (token) => token.cssCustomProperty == '--dp-type-body-large',
        );
        expect(reading.lightValue.fontFamily, DpTypography.family);
        expect(reading.lightValue.fontSize, 16);
        expect(reading.lightValue.height, 1.6);
        expect(
          reading.allowedUsages,
          contains(DpSemanticTokenUsage.readingTypography),
        );
      },
    );

    test('state mapping covers the complete v1 interaction contract', () {
      expect(
        DpSemanticTokenManifest.stateMappings.map((mapping) => mapping.state),
        DpSemanticState.values,
      );

      final focus = DpSemanticTokenManifest.stateMappings.singleWhere(
        (mapping) => mapping.state == DpSemanticState.focus,
      );
      expect(focus.focusRing, DpSemanticColorRole.primaryText);
      expect(focus.focusRingWidth, 2);
      expect(
        focus.resolve(DpColors.light).focusRing,
        DpColors.light.primaryText,
      );
      expect(focus.resolve(DpColors.dark).focusRing, DpColors.dark.primaryText);

      final error = DpSemanticTokenManifest.stateMappings.singleWhere(
        (mapping) => mapping.state == DpSemanticState.error,
      );
      expect(error.foreground, DpSemanticColorRole.danger);
      expect(error.border, DpSemanticColorRole.danger);
    });

    test(
      'CSS projection includes version, theme values and state mappings',
      () {
        final light = DpSemanticTokenManifest.cssCustomProperties(
          Brightness.light,
        );
        final dark = DpSemanticTokenManifest.cssCustomProperties(
          Brightness.dark,
        );

        expect(light['--dp-token-manifest-version'], '"1.0.0"');
        expect(light['--dp-color-primary'], '#B45309');
        expect(dark['--dp-color-primary'], '#F59E0B');
        expect(light['--dp-space-lg'], '16px');
        expect(light['--dp-state-focus-ring'], '#92400E');
        expect(dark['--dp-state-focus-ring'], '#FBBF24');
        expect(light['--dp-state-focus-ring-width'], '2px');
      },
    );
  });
}
