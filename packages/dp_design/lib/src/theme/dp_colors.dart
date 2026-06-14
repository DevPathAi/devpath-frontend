import 'package:flutter/material.dart';

/// 디자인 토큰(색). DESIGN.md §1 의 단일 출처를 코드화.
/// primary(면 전용)와 primaryText(텍스트/링크, ≥4.5:1) 분리(DD1).
@immutable
class DpColors extends ThemeExtension<DpColors> {
  const DpColors({
    required this.primary,
    required this.primaryText,
    required this.primaryTextStrong,
    required this.onPrimary,
    required this.bg,
    required this.surface,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.success,
    required this.warning,
    required this.danger,
    required this.codeEditorBg,
    required this.codeLogBg,
    required this.codeText,
  });

  final Color primary;
  final Color primaryText;
  final Color primaryTextStrong;
  final Color onPrimary;
  final Color bg;
  final Color surface;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color success;
  final Color warning;
  final Color danger;
  final Color codeEditorBg; // 항상 다크(토글 무관)
  final Color codeLogBg;
  final Color codeText;

  static const light = DpColors(
    primary: Color(0xFF6366F1),
    primaryText: Color(0xFF4F46E5),
    primaryTextStrong: Color(0xFF4338CA),
    onPrimary: Color(0xFFFFFFFF),
    bg: Color(0xFFF8FAFC),
    surface: Color(0xFFFFFFFF),
    border: Color(0xFFE2E8F0),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF64748B),
    success: Color(0xFF16A34A),
    warning: Color(0xFFCA8A04),
    danger: Color(0xFFDC2626),
    codeEditorBg: Color(0xFF1E1E1E),
    codeLogBg: Color(0xFF0D1117),
    codeText: Color(0xFFD4D4D4),
  );

  static const dark = DpColors(
    primary: Color(0xFF6366F1),
    primaryText: Color(0xFFA5B4FC),
    primaryTextStrong: Color(0xFFC7D2FE),
    onPrimary: Color(0xFFFFFFFF),
    bg: Color(0xFF0F172A),
    surface: Color(0xFF1E293B),
    border: Color(0xFF334155),
    textPrimary: Color(0xFFE2E8F0),
    textSecondary: Color(0xFF94A3B8),
    success: Color(0xFF16A34A),
    warning: Color(0xFFCA8A04),
    danger: Color(0xFFDC2626),
    codeEditorBg: Color(0xFF1E1E1E),
    codeLogBg: Color(0xFF0D1117),
    codeText: Color(0xFFC9D1D9),
  );

  @override
  DpColors copyWith({
    Color? primary,
    Color? primaryText,
    Color? primaryTextStrong,
    Color? onPrimary,
    Color? bg,
    Color? surface,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? success,
    Color? warning,
    Color? danger,
    Color? codeEditorBg,
    Color? codeLogBg,
    Color? codeText,
  }) =>
      DpColors(
        primary: primary ?? this.primary,
        primaryText: primaryText ?? this.primaryText,
        primaryTextStrong: primaryTextStrong ?? this.primaryTextStrong,
        onPrimary: onPrimary ?? this.onPrimary,
        bg: bg ?? this.bg,
        surface: surface ?? this.surface,
        border: border ?? this.border,
        textPrimary: textPrimary ?? this.textPrimary,
        textSecondary: textSecondary ?? this.textSecondary,
        success: success ?? this.success,
        warning: warning ?? this.warning,
        danger: danger ?? this.danger,
        codeEditorBg: codeEditorBg ?? this.codeEditorBg,
        codeLogBg: codeLogBg ?? this.codeLogBg,
        codeText: codeText ?? this.codeText,
      );

  @override
  DpColors lerp(ThemeExtension<DpColors>? other, double t) {
    if (other is! DpColors) return this;
    return DpColors(
      primary: Color.lerp(primary, other.primary, t)!,
      primaryText: Color.lerp(primaryText, other.primaryText, t)!,
      primaryTextStrong: Color.lerp(primaryTextStrong, other.primaryTextStrong, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      border: Color.lerp(border, other.border, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      codeEditorBg: Color.lerp(codeEditorBg, other.codeEditorBg, t)!,
      codeLogBg: Color.lerp(codeLogBg, other.codeLogBg, t)!,
      codeText: Color.lerp(codeText, other.codeText, t)!,
    );
  }
}
