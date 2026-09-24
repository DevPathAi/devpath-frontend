import 'package:flutter/material.dart';

import 'dp_colors.dart';
import 'dp_spacing.dart';
import 'dp_typography.dart';

/// Landing과 Flutter가 공유하는 versioned semantic-token manifest의 종류.
enum DpSemanticTokenKind {
  color,
  spacing,
  radius,
  density,
  duration,
  typography,
}

/// 토큰을 raw 색/수치가 아니라 허용된 역할로 소비하게 하는 계약.
enum DpSemanticTokenUsage {
  ground,
  raisedSurface,
  mutedSurface,
  structuralBorder,
  primaryAction,
  currentProgress,
  earnedCompletion,
  focusIndicator,
  primaryText,
  secondaryText,
  metadata,
  navigation,
  success,
  warning,
  error,
  tag,
  dataVisualization,
  code,
  layoutSpacing,
  panelShape,
  interactionDensity,
  motion,
  uiTypography,
  readingTypography,
}

@immutable
abstract class DpSemanticToken<T> {
  const DpSemanticToken({
    required this.kind,
    required this.flutterName,
    required this.cssCustomProperty,
    required this.lightValue,
    required this.darkValue,
    required this.allowedUsages,
  });

  final DpSemanticTokenKind kind;
  final String flutterName;
  final String cssCustomProperty;
  final T lightValue;
  final T darkValue;
  final Set<DpSemanticTokenUsage> allowedUsages;

  T valueFor(Brightness brightness) =>
      brightness == Brightness.dark ? darkValue : lightValue;

  String cssValueFor(Brightness brightness);
}

/// [DpColors]의 필드를 문자열 lookup 없이 참조하는 typed mapping.
enum DpSemanticColorRole {
  primary,
  primaryText,
  primaryTextStrong,
  onPrimary,
  accentSoft,
  accentLine,
  bg,
  surface,
  surfaceMuted,
  border,
  textPrimary,
  textSecondary,
  textFaint,
  headerBg,
  headerText,
  headerMuted,
  headerFaint,
  headerActive,
  headerBorder,
  success,
  warning,
  danger,
  tagBg,
  tagText,
  chart1,
  chart2,
  chart3,
  chart4,
  chart5,
  codeEditorBg,
  codeLogBg,
  codeText,
}

extension DpSemanticColorRoleX on DpSemanticColorRole {
  String get flutterName => 'DpColors.$name';

  String get cssCustomProperty => '--dp-color-${_kebabCase(name)}';

  Color resolve(DpColors colors) => switch (this) {
    DpSemanticColorRole.primary => colors.primary,
    DpSemanticColorRole.primaryText => colors.primaryText,
    DpSemanticColorRole.primaryTextStrong => colors.primaryTextStrong,
    DpSemanticColorRole.onPrimary => colors.onPrimary,
    DpSemanticColorRole.accentSoft => colors.accentSoft,
    DpSemanticColorRole.accentLine => colors.accentLine,
    DpSemanticColorRole.bg => colors.bg,
    DpSemanticColorRole.surface => colors.surface,
    DpSemanticColorRole.surfaceMuted => colors.surfaceMuted,
    DpSemanticColorRole.border => colors.border,
    DpSemanticColorRole.textPrimary => colors.textPrimary,
    DpSemanticColorRole.textSecondary => colors.textSecondary,
    DpSemanticColorRole.textFaint => colors.textFaint,
    DpSemanticColorRole.headerBg => colors.headerBg,
    DpSemanticColorRole.headerText => colors.headerText,
    DpSemanticColorRole.headerMuted => colors.headerMuted,
    DpSemanticColorRole.headerFaint => colors.headerFaint,
    DpSemanticColorRole.headerActive => colors.headerActive,
    DpSemanticColorRole.headerBorder => colors.headerBorder,
    DpSemanticColorRole.success => colors.success,
    DpSemanticColorRole.warning => colors.warning,
    DpSemanticColorRole.danger => colors.danger,
    DpSemanticColorRole.tagBg => colors.tagBg,
    DpSemanticColorRole.tagText => colors.tagText,
    DpSemanticColorRole.chart1 => colors.chart1,
    DpSemanticColorRole.chart2 => colors.chart2,
    DpSemanticColorRole.chart3 => colors.chart3,
    DpSemanticColorRole.chart4 => colors.chart4,
    DpSemanticColorRole.chart5 => colors.chart5,
    DpSemanticColorRole.codeEditorBg => colors.codeEditorBg,
    DpSemanticColorRole.codeLogBg => colors.codeLogBg,
    DpSemanticColorRole.codeText => colors.codeText,
  };

  Set<DpSemanticTokenUsage> get allowedUsages => switch (this) {
    DpSemanticColorRole.primary => const {
      DpSemanticTokenUsage.primaryAction,
      DpSemanticTokenUsage.currentProgress,
      DpSemanticTokenUsage.earnedCompletion,
    },
    DpSemanticColorRole.primaryText => const {
      DpSemanticTokenUsage.primaryText,
      DpSemanticTokenUsage.focusIndicator,
    },
    DpSemanticColorRole.primaryTextStrong => const {
      DpSemanticTokenUsage.primaryText,
      DpSemanticTokenUsage.earnedCompletion,
    },
    DpSemanticColorRole.onPrimary => const {DpSemanticTokenUsage.primaryAction},
    DpSemanticColorRole.accentSoft || DpSemanticColorRole.accentLine => const {
      DpSemanticTokenUsage.currentProgress,
      DpSemanticTokenUsage.earnedCompletion,
    },
    DpSemanticColorRole.bg => const {DpSemanticTokenUsage.ground},
    DpSemanticColorRole.surface => const {DpSemanticTokenUsage.raisedSurface},
    DpSemanticColorRole.surfaceMuted => const {
      DpSemanticTokenUsage.mutedSurface,
    },
    DpSemanticColorRole.border => const {DpSemanticTokenUsage.structuralBorder},
    DpSemanticColorRole.textPrimary => const {DpSemanticTokenUsage.primaryText},
    DpSemanticColorRole.textSecondary => const {
      DpSemanticTokenUsage.secondaryText,
    },
    DpSemanticColorRole.textFaint => const {DpSemanticTokenUsage.metadata},
    DpSemanticColorRole.headerBg ||
    DpSemanticColorRole.headerText ||
    DpSemanticColorRole.headerMuted ||
    DpSemanticColorRole.headerFaint ||
    DpSemanticColorRole.headerActive ||
    DpSemanticColorRole.headerBorder => const {DpSemanticTokenUsage.navigation},
    DpSemanticColorRole.success => const {
      DpSemanticTokenUsage.success,
      DpSemanticTokenUsage.earnedCompletion,
    },
    DpSemanticColorRole.warning => const {DpSemanticTokenUsage.warning},
    DpSemanticColorRole.danger => const {DpSemanticTokenUsage.error},
    DpSemanticColorRole.tagBg ||
    DpSemanticColorRole.tagText => const {DpSemanticTokenUsage.tag},
    DpSemanticColorRole.chart1 ||
    DpSemanticColorRole.chart2 ||
    DpSemanticColorRole.chart3 ||
    DpSemanticColorRole.chart4 ||
    DpSemanticColorRole.chart5 => const {
      DpSemanticTokenUsage.dataVisualization,
    },
    DpSemanticColorRole.codeEditorBg ||
    DpSemanticColorRole.codeLogBg ||
    DpSemanticColorRole.codeText => const {DpSemanticTokenUsage.code},
  };
}

final class DpSemanticColorToken extends DpSemanticToken<Color> {
  DpSemanticColorToken(this.role)
    : super(
        kind: DpSemanticTokenKind.color,
        flutterName: role.flutterName,
        cssCustomProperty: role.cssCustomProperty,
        lightValue: role.resolve(DpColors.light),
        darkValue: role.resolve(DpColors.dark),
        allowedUsages: role.allowedUsages,
      );

  final DpSemanticColorRole role;

  @override
  String cssValueFor(Brightness brightness) =>
      _colorToCss(valueFor(brightness));
}

enum _SpacingRole { xs, sm, md, lg, xl, xxl, xxxl }

extension on _SpacingRole {
  double get value => switch (this) {
    _SpacingRole.xs => DpSpacing.xs,
    _SpacingRole.sm => DpSpacing.sm,
    _SpacingRole.md => DpSpacing.md,
    _SpacingRole.lg => DpSpacing.lg,
    _SpacingRole.xl => DpSpacing.xl,
    _SpacingRole.xxl => DpSpacing.xxl,
    _SpacingRole.xxxl => DpSpacing.xxxl,
  };
}

enum _RadiusRole { chip, button, panel, input, dialog }

extension on _RadiusRole {
  double get value => switch (this) {
    _RadiusRole.chip => DpRadius.chip,
    _RadiusRole.button => DpRadius.button,
    _RadiusRole.panel => DpRadius.card,
    _RadiusRole.input => DpRadius.input,
    _RadiusRole.dialog => DpRadius.dialog,
  };

  String get flutterName => switch (this) {
    _RadiusRole.panel => 'DpRadius.card',
    _ => 'DpRadius.$name',
  };
}

enum _DensityRole { controlHeight, rowPadding, minTarget }

extension on _DensityRole {
  double get value => switch (this) {
    _DensityRole.controlHeight => DpDensity.controlHeight,
    _DensityRole.rowPadding => DpDensity.rowPadding,
    _DensityRole.minTarget => DpDensity.minTarget,
  };
}

final class DpSemanticDimensionToken extends DpSemanticToken<double> {
  const DpSemanticDimensionToken({
    required super.kind,
    required super.flutterName,
    required super.cssCustomProperty,
    required double value,
    required super.allowedUsages,
  }) : super(lightValue: value, darkValue: value);

  @override
  String cssValueFor(Brightness brightness) =>
      '${_formatNumber(valueFor(brightness))}px';
}

enum _DurationRole {
  stageReveal,
  skeletonCrossfade,
  hover,
  select,
  panelExpand,
}

extension on _DurationRole {
  Duration get value => switch (this) {
    _DurationRole.stageReveal => DpDurations.stageReveal,
    _DurationRole.skeletonCrossfade => DpDurations.skeletonCrossfade,
    _DurationRole.hover => DpDurations.hover,
    _DurationRole.select => DpDurations.select,
    _DurationRole.panelExpand => DpDurations.panelExpand,
  };
}

final class DpSemanticDurationToken extends DpSemanticToken<Duration> {
  const DpSemanticDurationToken({
    required super.flutterName,
    required super.cssCustomProperty,
    required Duration value,
  }) : super(
         kind: DpSemanticTokenKind.duration,
         lightValue: value,
         darkValue: value,
         allowedUsages: const {DpSemanticTokenUsage.motion},
       );

  @override
  String cssValueFor(Brightness brightness) =>
      '${valueFor(brightness).inMilliseconds}ms';
}

enum _TypographyRole {
  displaySmall,
  headlineSmall,
  titleLarge,
  titleMedium,
  titleSmall,
  bodyLarge,
  bodyMedium,
  bodySmall,
  labelLarge,
  labelMedium,
  labelSmall,
  code,
}

extension on _TypographyRole {
  TextStyle resolve(Brightness brightness) {
    if (this == _TypographyRole.code) return DpTypography.code;
    final theme = DpTypography.textTheme(brightness);
    return switch (this) {
      _TypographyRole.displaySmall => theme.displaySmall!,
      _TypographyRole.headlineSmall => theme.headlineSmall!,
      _TypographyRole.titleLarge => theme.titleLarge!,
      _TypographyRole.titleMedium => theme.titleMedium!,
      _TypographyRole.titleSmall => theme.titleSmall!,
      _TypographyRole.bodyLarge => theme.bodyLarge!,
      _TypographyRole.bodyMedium => theme.bodyMedium!,
      _TypographyRole.bodySmall => theme.bodySmall!,
      _TypographyRole.labelLarge => theme.labelLarge!,
      _TypographyRole.labelMedium => theme.labelMedium!,
      _TypographyRole.labelSmall => theme.labelSmall!,
      _TypographyRole.code => DpTypography.code,
    };
  }

  Set<DpSemanticTokenUsage> get usages => switch (this) {
    _TypographyRole.bodyLarge => const {DpSemanticTokenUsage.readingTypography},
    _TypographyRole.code => const {DpSemanticTokenUsage.code},
    _ => const {DpSemanticTokenUsage.uiTypography},
  };
}

final class DpSemanticTypographyToken extends DpSemanticToken<TextStyle> {
  DpSemanticTypographyToken._(_TypographyRole role)
    : super(
        kind: DpSemanticTokenKind.typography,
        flutterName: role == _TypographyRole.code
            ? 'DpTypography.code'
            : 'DpTypography.textTheme.${role.name}',
        cssCustomProperty: '--dp-type-${_kebabCase(role.name)}',
        lightValue: role.resolve(Brightness.light),
        darkValue: role.resolve(Brightness.dark),
        allowedUsages: role.usages,
      );

  @override
  String cssValueFor(Brightness brightness) {
    final style = valueFor(brightness);
    final size = style.fontSize!;
    final lineHeight = size * (style.height ?? 1);
    final weight = style.fontWeight?.value ?? FontWeight.normal.value;
    return '$weight ${_formatNumber(size)}px/'
        '${_formatNumber(lineHeight)}px "${style.fontFamily}"';
  }
}

/// 공용 interactive state contract. 상태 자체가 색을 소유하지 않고
/// [DpSemanticColorRole]을 참조하므로 light/dark 값은 항상 DpColors에서 온다.
enum DpSemanticState {
  defaultState,
  hover,
  pressed,
  focus,
  selected,
  disabled,
  error,
}

@immutable
class DpResolvedSemanticState {
  const DpResolvedSemanticState({
    required this.background,
    required this.foreground,
    required this.border,
    required this.focusRing,
    required this.focusRingWidth,
    required this.opacity,
  });

  final Color background;
  final Color foreground;
  final Color border;
  final Color? focusRing;
  final double focusRingWidth;
  final double opacity;
}

@immutable
class DpSemanticStateMapping {
  const DpSemanticStateMapping({
    required this.state,
    required this.background,
    required this.foreground,
    required this.border,
    this.focusRing,
    this.focusRingWidth = 0,
    this.opacity = 1,
  });

  final DpSemanticState state;
  final DpSemanticColorRole background;
  final DpSemanticColorRole foreground;
  final DpSemanticColorRole border;
  final DpSemanticColorRole? focusRing;
  final double focusRingWidth;
  final double opacity;

  String get cssName => state == DpSemanticState.defaultState
      ? 'default'
      : _kebabCase(state.name);

  DpResolvedSemanticState resolve(DpColors colors) => DpResolvedSemanticState(
    background: background.resolve(colors),
    foreground: foreground.resolve(colors),
    border: border.resolve(colors),
    focusRing: focusRing?.resolve(colors),
    focusRingWidth: focusRingWidth,
    opacity: opacity,
  );
}

/// 2.0.0 manifest(웹 문법). 값은 DpColors/DpSpacing/DpRadius/DpDensity/DpTypography 에서
/// 읽으며 Landing mirror 가 사용할 CSS 이름과 상태 mapping 을 함께 고정한다.
abstract final class DpSemanticTokenManifest {
  static const String schema = 'leva.semantic-tokens';
  static const String version = '2.0.0';

  static final List<DpSemanticColorToken> colors = List.unmodifiable(
    DpSemanticColorRole.values.map(DpSemanticColorToken.new),
  );

  static final List<DpSemanticDimensionToken> spacing = List.unmodifiable(
    _SpacingRole.values.map(
      (role) => DpSemanticDimensionToken(
        kind: DpSemanticTokenKind.spacing,
        flutterName: 'DpSpacing.${role.name}',
        cssCustomProperty: '--dp-space-${role.name}',
        value: role.value,
        allowedUsages: const {DpSemanticTokenUsage.layoutSpacing},
      ),
    ),
  );

  static final List<DpSemanticDimensionToken> radii = List.unmodifiable(
    _RadiusRole.values.map(
      (role) => DpSemanticDimensionToken(
        kind: DpSemanticTokenKind.radius,
        flutterName: role.flutterName,
        cssCustomProperty: '--dp-radius-${role.name}',
        value: role.value,
        allowedUsages: const {DpSemanticTokenUsage.panelShape},
      ),
    ),
  );

  /// 포인터 밀도(2.0.0 신설). 컨트롤 높이·표 행 여백·최소 타깃 — DpDensity 가 SSoT.
  static final List<DpSemanticDimensionToken> density = List.unmodifiable(
    _DensityRole.values.map(
      (role) => DpSemanticDimensionToken(
        kind: DpSemanticTokenKind.density,
        flutterName: 'DpDensity.${role.name}',
        cssCustomProperty: '--dp-density-${_kebabCase(role.name)}',
        value: role.value,
        allowedUsages: const {DpSemanticTokenUsage.interactionDensity},
      ),
    ),
  );

  static final List<DpSemanticDurationToken> durations = List.unmodifiable(
    _DurationRole.values.map(
      (role) => DpSemanticDurationToken(
        flutterName: 'DpDurations.${role.name}',
        cssCustomProperty: '--dp-duration-${_kebabCase(role.name)}',
        value: role.value,
      ),
    ),
  );

  static final List<DpSemanticTypographyToken> typography = List.unmodifiable(
    _TypographyRole.values.map(DpSemanticTypographyToken._),
  );

  static final List<DpSemanticToken<Object>> tokens = List.unmodifiable([
    ...colors,
    ...spacing,
    ...radii,
    ...density,
    ...durations,
    ...typography,
  ]);

  static const List<DpSemanticStateMapping> stateMappings = [
    DpSemanticStateMapping(
      state: DpSemanticState.defaultState,
      background: DpSemanticColorRole.surface,
      foreground: DpSemanticColorRole.textPrimary,
      border: DpSemanticColorRole.border,
    ),
    DpSemanticStateMapping(
      state: DpSemanticState.hover,
      background: DpSemanticColorRole.surfaceMuted,
      foreground: DpSemanticColorRole.textPrimary,
      border: DpSemanticColorRole.border,
    ),
    DpSemanticStateMapping(
      state: DpSemanticState.pressed,
      background: DpSemanticColorRole.surfaceMuted,
      foreground: DpSemanticColorRole.textPrimary,
      border: DpSemanticColorRole.primaryTextStrong,
    ),
    DpSemanticStateMapping(
      state: DpSemanticState.focus,
      background: DpSemanticColorRole.surface,
      foreground: DpSemanticColorRole.textPrimary,
      border: DpSemanticColorRole.border,
      focusRing: DpSemanticColorRole.primaryText,
      focusRingWidth: 2,
    ),
    DpSemanticStateMapping(
      state: DpSemanticState.selected,
      background: DpSemanticColorRole.accentSoft,
      foreground: DpSemanticColorRole.primaryTextStrong,
      border: DpSemanticColorRole.accentLine,
    ),
    DpSemanticStateMapping(
      state: DpSemanticState.disabled,
      background: DpSemanticColorRole.surfaceMuted,
      foreground: DpSemanticColorRole.textSecondary,
      border: DpSemanticColorRole.border,
      opacity: 0.56,
    ),
    DpSemanticStateMapping(
      state: DpSemanticState.error,
      background: DpSemanticColorRole.surface,
      foreground: DpSemanticColorRole.danger,
      border: DpSemanticColorRole.danger,
    ),
  ];

  /// Landing의 tokens.css가 mirror할 수 있는 평탄한 값 projection.
  static Map<String, String> cssCustomProperties(Brightness brightness) {
    final properties = <String, String>{
      '--dp-token-manifest-version': '"$version"',
      for (final token in tokens)
        token.cssCustomProperty: token.cssValueFor(brightness),
    };
    final colors = brightness == Brightness.dark
        ? DpColors.dark
        : DpColors.light;
    for (final mapping in stateMappings) {
      final resolved = mapping.resolve(colors);
      final prefix = '--dp-state-${mapping.cssName}';
      properties['$prefix-background'] = _colorToCss(resolved.background);
      properties['$prefix-foreground'] = _colorToCss(resolved.foreground);
      properties['$prefix-border'] = _colorToCss(resolved.border);
      if (resolved.focusRing != null) {
        properties['$prefix-ring'] = _colorToCss(resolved.focusRing!);
        properties['$prefix-ring-width'] =
            '${_formatNumber(resolved.focusRingWidth)}px';
      }
      if (resolved.opacity != 1) {
        properties['$prefix-opacity'] = _formatNumber(resolved.opacity);
      }
    }
    return Map.unmodifiable(properties);
  }
}

String _kebabCase(String value) => value
    .replaceAllMapped(
      RegExp(r'([a-z0-9])([A-Z])'),
      (match) => '${match.group(1)}-${match.group(2)}',
    )
    .toLowerCase();

/// 3자리로 반올림한 뒤 뒤따르는 0과 소수점을 지운다. `22 * (30 / 22)` 처럼
/// 부동소수점 오차가 있는 값(30.000000000000004)도 `30` 으로 찍힌다.
String _formatNumber(num value) {
  final trimmed = value.toStringAsFixed(3).replaceFirst(RegExp(r'\.?0+$'), '');
  return trimmed.isEmpty ? '0' : trimmed;
}

String _colorToCss(Color color) {
  final argb = color.toARGB32();
  final rgb = argb & 0x00FFFFFF;
  return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}
