import 'package:flutter/material.dart';

import 'dp_colors.dart';
import 'dp_tokens.dart';
import 'dp_typography.dart';

/// DESIGN.md 토큰을 ThemeData로 조립. 타이포는 Task 2에서 textTheme 주입.
abstract final class DpTheme {
  static ThemeData light() => _build(Brightness.light, DpColors.light);
  static ThemeData dark() => _build(Brightness.dark, DpColors.dark);

  static ThemeData _build(Brightness brightness, DpColors c) {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: const Color(0xFFB45309), // T2 앰버 액센트 시드
          brightness: brightness,
        ).copyWith(
          // P3-B: scheme.primary는 접근성 변형(primaryText, ≥4.5:1)으로 둔다.
          // 스톡 Material 텍스트 위젯(TextButton 등)이 이 색을 텍스트로 쓰기 때문.
          // 밝은 채움색(T2 앰버, light #B45309/dark #F59E0B)이 필요한 면은
          // 컴포넌트가 context.dpColors.primary를 명시 사용.
          primary: c.primaryText,
          onPrimary: c.onPrimary,
          surface: c.surface,
          error: c.danger,
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
      // 포커스 가시성(DD7): 2px primaryText 링은 컴포넌트에서 FocusRing로 적용.
    );
  }
}
