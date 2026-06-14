import 'package:flutter/material.dart';

import 'dp_colors.dart';

/// DESIGN.md 토큰을 ThemeData로 조립. 타이포는 Task 2에서 textTheme 주입.
abstract final class DpTheme {
  static ThemeData light() => _build(Brightness.light, DpColors.light);
  static ThemeData dark() => _build(Brightness.dark, DpColors.dark);

  static ThemeData _build(Brightness brightness, DpColors c) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF4F46E5), // indigo-600 시드(DD1)
      brightness: brightness,
    ).copyWith(
      // P3-B: scheme.primary는 접근성 변형(primaryText, ≥4.5:1)으로 둔다.
      // 스톡 Material 텍스트 위젯(TextButton 등)이 이 색을 텍스트로 쓰기 때문.
      // 밝은 fill(#6366f1)이 필요한 면은 컴포넌트가 context.dpColors.primary를 명시 사용.
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
      extensions: [c],
      // 포커스 가시성(DD7): 2px primaryText 링은 컴포넌트에서 FocusRing로 적용.
    );
  }
}

/// 토큰 접근 단축: `context.dpColors.primaryText`.
extension DpColorsX on BuildContext {
  DpColors get dpColors => Theme.of(this).extension<DpColors>()!;
}
