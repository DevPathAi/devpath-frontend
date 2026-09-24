import 'package:flutter/material.dart';

import 'dp_colors.dart';
import 'dp_spacing.dart';
import 'dp_tokens.dart';
import 'dp_typography.dart';

/// Leva v2 제품 UI의 전역 시각 언어를 조립한다.
abstract final class DpTheme {
  static ThemeData light() => _build(Brightness.light, DpColors.light);
  static ThemeData dark() => _build(Brightness.dark, DpColors.dark);

  static ThemeData _build(Brightness brightness, DpColors c) {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: c.primary,
          brightness: brightness,
        ).copyWith(
          // scheme.primary는 접근성 변형(primaryText, ≥4.5:1)으로 둔다.
          // 스톡 Material 텍스트 위젯(TextButton 등)이 이 색을 텍스트로 쓰기 때문.
          // 브랜드 인디고 채움이 필요한 면은
          // 컴포넌트가 context.dpColors.primary를 명시 사용.
          primary: c.primaryText,
          onPrimary: c.onPrimary,
          surface: c.surface,
          error: c.danger,
        );
    final roundedButton = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(DpRadius.button),
    );
    final roundedInput = OutlineInputBorder(
      borderRadius: BorderRadius.circular(DpRadius.input),
      borderSide: BorderSide(color: c.border),
    );
    final controlText = WidgetStatePropertyAll(
      DpTypography.textTheme(brightness).labelLarge,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.bg,
      textTheme: DpTypography.textTheme(
        brightness,
      ).apply(bodyColor: c.textPrimary, displayColor: c.textPrimary),
      fontFamily: DpTypography.family,
      extensions: [c, AppTokens.standard],
      splashFactory: InkSparkle.splashFactory,
      dividerColor: c.border,
      dividerTheme: DividerThemeData(color: c.border, thickness: 1),
      // 계약 2.0.0(스펙 §5.4-1 "촘촘"): 컨트롤 30px, 최소 포인터 타깃 24px(WCAG 2.2 AA 2.5.8).
      // 플랫폼 밀도에 기대지 않고 minimumSize 로 고정한다. tapTargetSize 는 shrinkWrap —
      // padded 는 레이아웃 크기를 48px 로 부풀려 30px 컨트롤을 만들 수 없다.
      visualDensity: VisualDensity.standard,
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: DpSpacing.md, vertical: 5),
          ),
          minimumSize: const WidgetStatePropertyAll(
            Size(DpDensity.minTarget, DpDensity.controlHeight),
          ),
          // SegmentedButton 은 minimumSize 를 세그먼트에 전달하지 않고 자체 하한
          // (textButtonMinHeight 40 + visualDensity.baseSizeAdjustment.dy)으로 높이를
          // 정한다(segmented_button.dart). compact 밀도가 그 하한을 32px 로 낮춘다.
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          textStyle: controlText,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(
            Size(64, DpDensity.controlHeight),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: DpSpacing.lg),
          ),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: WidgetStatePropertyAll(roundedButton),
          textStyle: controlText,
          elevation: const WidgetStatePropertyAll(0),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? c.surfaceMuted
                : c.primary,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? c.textFaint
                : c.onPrimary,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(
            Size(64, DpDensity.controlHeight),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: DpSpacing.lg),
          ),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: WidgetStatePropertyAll(roundedButton),
          textStyle: controlText,
          foregroundColor: WidgetStatePropertyAll(c.textPrimary),
          side: WidgetStatePropertyAll(BorderSide(color: c.border)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(
            Size(DpDensity.minTarget, DpDensity.controlHeight),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: DpSpacing.sm),
          ),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: WidgetStatePropertyAll(roundedButton),
          textStyle: controlText,
          foregroundColor: WidgetStatePropertyAll(c.primaryText),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(
            Size(DpDensity.controlHeight, DpDensity.controlHeight),
          ),
          padding: const WidgetStatePropertyAll(EdgeInsets.all(3)),
          iconSize: const WidgetStatePropertyAll(20),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: WidgetStatePropertyAll(roundedButton),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        isDense: true,
        fillColor: c.surfaceMuted,
        constraints: const BoxConstraints(minHeight: DpDensity.controlHeight),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: DpSpacing.md,
          vertical: 5,
        ),
        border: roundedInput,
        enabledBorder: roundedInput,
        focusedBorder: roundedInput.copyWith(
          borderSide: BorderSide(color: c.primaryText, width: 2),
        ),
        hintStyle: TextStyle(color: c.textFaint),
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: c.border),
          borderRadius: BorderRadius.circular(DpRadius.card),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.tagBg,
        selectedColor: c.accentSoft,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DpRadius.chip),
        ),
        labelStyle: TextStyle(color: c.tagText),
        padding: const EdgeInsets.symmetric(horizontal: DpSpacing.sm),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: c.border),
          borderRadius: BorderRadius.circular(DpRadius.dialog),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        modalBackgroundColor: c.surface,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(DpRadius.dialog),
          ),
          side: BorderSide(color: c.border),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.primary,
        foregroundColor: c.onPrimary,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DpRadius.button),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.primary,
        linearTrackColor: c.surfaceMuted,
        circularTrackColor: c.surfaceMuted,
      ),
      // 포커스 가시성(DD7): 2px primaryText 링은 컴포넌트에서 FocusRing로 적용.
    );
  }
}
