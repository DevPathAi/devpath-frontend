import 'package:flutter/material.dart';

/// 디자인 토큰(색). DESIGN.md §1 의 단일 출처를 코드화.
///
/// 팔레트는 **T2 잉크·앰버**. 따뜻한 무채색 그라운드에 앰버 하나를 액센트로 쓴다.
/// 앰버는 "성취"(진행률·스트릭·1차 행동)를 전담한다.
///
/// 이름 규칙: `primary` 는 **채움 전용**, 텍스트는 `primaryText`(≥4.5:1),
/// 12~14px 강조는 `primaryTextStrong`(≥7:1). 이 분리는 인디고 시절부터의 계약이며
/// 47개 파일이 이 이름에 의존하므로 개명하지 않는다.
///
/// ⚠️ 필드를 추가하면 [copyWith] 와 [lerp] 도 함께 고쳐야 한다.
/// 셋이 어긋나면 테마 전환에서 해당 토큰만 튄다(dp_colors_integrity_test 가 지킨다).
@immutable
class DpColors extends ThemeExtension<DpColors> {
  const DpColors({
    required this.primary,
    required this.primaryText,
    required this.primaryTextStrong,
    required this.onPrimary,
    required this.accentSoft,
    required this.accentLine,
    required this.bg,
    required this.surface,
    required this.surfaceMuted,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textFaint,
    required this.railBg,
    required this.railText,
    required this.railMuted,
    required this.railFaint,
    required this.railActive,
    required this.railBorder,
    required this.success,
    required this.warning,
    required this.danger,
    required this.tagBg,
    required this.tagText,
    required this.chart1,
    required this.chart2,
    required this.chart3,
    required this.chart4,
    required this.chart5,
    required this.codeEditorBg,
    required this.codeLogBg,
    required this.codeText,
  });

  /// 채움 전용. 텍스트에 쓰지 않는다.
  final Color primary;
  final Color primaryText;
  final Color primaryTextStrong;

  /// [primary] 채움 위 텍스트. **다크에서는 어두운 색**이다(앰버 위 흰 텍스트는 대비 미달).
  final Color onPrimary;

  /// 1차 카드 배경·뱃지.
  final Color accentSoft;

  /// 1차 카드 보더.
  final Color accentLine;

  final Color bg;
  final Color surface;

  /// 비활성·보조 면. 카드(surface)와 배경(bg) 사이 단계.
  final Color surfaceMuted;

  final Color border;
  final Color textPrimary;
  final Color textSecondary;

  /// 메타·캡션. UI 컴포넌트 기준(3:1)이라 **본문 텍스트로 쓰지 않는다.**
  final Color textFaint;

  /// 사이드바 전용. 본문과 다른 위계를 갖는다.
  final Color railBg;
  final Color railText;
  final Color railMuted;

  /// 사이드바 섹션 레이블.
  final Color railFaint;
  final Color railActive;
  final Color railBorder;

  final Color success;

  /// **진짜 경고 전용.** 서비스 상태(점검·한도·오프라인)는 중립을 쓰고,
  /// 구분용 색은 [chart4] 를 쓴다. 액센트(앰버)와 계열이 가까워 용도를 좁혔다.
  final Color warning;

  final Color danger;

  final Color tagBg;
  final Color tagText;

  /// 차트 팔레트. chart4 는 앰버의 대비 계열(틸)이라 구분용 색으로도 쓴다.
  final Color chart1;
  final Color chart2;
  final Color chart3;
  final Color chart4;
  final Color chart5;

  final Color codeEditorBg; // 항상 다크(토글 무관)
  final Color codeLogBg;
  final Color codeText;

  static const light = DpColors(
    primary: Color(0xFFB45309),
    primaryText: Color(0xFF92400E),
    primaryTextStrong: Color(0xFF78350F),
    onPrimary: Color(0xFFFFFFFF),
    accentSoft: Color(0xFFFDF1E0),
    accentLine: Color(0xFFF2D0A0),
    bg: Color(0xFFFAF9F7),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFF2F0EC),
    border: Color(0xFFE2DED7),
    textPrimary: Color(0xFF1A1815),
    textSecondary: Color(0xFF615C54),
    textFaint: Color(0xFF918B81),
    railBg: Color(0xFF1A1815),
    railText: Color(0xFFF2F0EC),
    railMuted: Color(0xFFA9A298),
    railFaint: Color(0xFF7D766C),
    railActive: Color(0xFF2F2B24),
    railBorder: Color(0xFF2B2823),
    success: Color(0xFF15803D),
    warning: Color(0xFFA16207),
    danger: Color(0xFFB91C1C),
    tagBg: Color(0xFFF2F0EC),
    tagText: Color(0xFF524D45),
    chart1: Color(0xFFB45309),
    chart2: Color(0xFFF2D0A0),
    chart3: Color(0xFF78350F),
    chart4: Color(0xFF0F766E),
    chart5: Color(0xFF8B857D),
    codeEditorBg: Color(0xFF1E1E1E),
    codeLogBg: Color(0xFF0D1117),
    codeText: Color(0xFFD4D4D4),
  );

  static const dark = DpColors(
    primary: Color(0xFFF59E0B),
    primaryText: Color(0xFFFBBF24),
    primaryTextStrong: Color(0xFFFCD34D),
    // ★라이트와 반대 방향★ 앰버 위 흰 텍스트는 2.2:1 로 미달한다.
    onPrimary: Color(0xFF1A1200),
    accentSoft: Color(0xFF2E2007),
    accentLine: Color(0xFF5C400E),
    bg: Color(0xFF0F0E0C),
    surface: Color(0xFF1A1815),
    surfaceMuted: Color(0xFF231F1B),
    border: Color(0xFF332E28),
    textPrimary: Color(0xFFEAE7E2),
    textSecondary: Color(0xFFA09991),
    textFaint: Color(0xFF6F6961),
    railBg: Color(0xFF131210),
    railText: Color(0xFFEAE7E2),
    railMuted: Color(0xFF948D85),
    railFaint: Color(0xFF6B655D),
    railActive: Color(0xFF231F1B),
    railBorder: Color(0xFF2A2621),
    success: Color(0xFF4ADE80),
    warning: Color(0xFFFCD34D),
    danger: Color(0xFFF87171),
    tagBg: Color(0xFF231F1B),
    tagText: Color(0xFFA09991),
    chart1: Color(0xFFF59E0B),
    chart2: Color(0xFF78350F),
    chart3: Color(0xFFFCD34D),
    chart4: Color(0xFF2DD4BF),
    chart5: Color(0xFF8B857D),
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
    Color? accentSoft,
    Color? accentLine,
    Color? bg,
    Color? surface,
    Color? surfaceMuted,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? textFaint,
    Color? railBg,
    Color? railText,
    Color? railMuted,
    Color? railFaint,
    Color? railActive,
    Color? railBorder,
    Color? success,
    Color? warning,
    Color? danger,
    Color? tagBg,
    Color? tagText,
    Color? chart1,
    Color? chart2,
    Color? chart3,
    Color? chart4,
    Color? chart5,
    Color? codeEditorBg,
    Color? codeLogBg,
    Color? codeText,
  }) => DpColors(
    primary: primary ?? this.primary,
    primaryText: primaryText ?? this.primaryText,
    primaryTextStrong: primaryTextStrong ?? this.primaryTextStrong,
    onPrimary: onPrimary ?? this.onPrimary,
    accentSoft: accentSoft ?? this.accentSoft,
    accentLine: accentLine ?? this.accentLine,
    bg: bg ?? this.bg,
    surface: surface ?? this.surface,
    surfaceMuted: surfaceMuted ?? this.surfaceMuted,
    border: border ?? this.border,
    textPrimary: textPrimary ?? this.textPrimary,
    textSecondary: textSecondary ?? this.textSecondary,
    textFaint: textFaint ?? this.textFaint,
    railBg: railBg ?? this.railBg,
    railText: railText ?? this.railText,
    railMuted: railMuted ?? this.railMuted,
    railFaint: railFaint ?? this.railFaint,
    railActive: railActive ?? this.railActive,
    railBorder: railBorder ?? this.railBorder,
    success: success ?? this.success,
    warning: warning ?? this.warning,
    danger: danger ?? this.danger,
    tagBg: tagBg ?? this.tagBg,
    tagText: tagText ?? this.tagText,
    chart1: chart1 ?? this.chart1,
    chart2: chart2 ?? this.chart2,
    chart3: chart3 ?? this.chart3,
    chart4: chart4 ?? this.chart4,
    chart5: chart5 ?? this.chart5,
    codeEditorBg: codeEditorBg ?? this.codeEditorBg,
    codeLogBg: codeLogBg ?? this.codeLogBg,
    codeText: codeText ?? this.codeText,
  );

  @override
  DpColors lerp(ThemeExtension<DpColors>? other, double t) {
    if (other is! DpColors) return this;
    Color m(Color a, Color b) => Color.lerp(a, b, t)!;
    return DpColors(
      primary: m(primary, other.primary),
      primaryText: m(primaryText, other.primaryText),
      primaryTextStrong: m(primaryTextStrong, other.primaryTextStrong),
      onPrimary: m(onPrimary, other.onPrimary),
      accentSoft: m(accentSoft, other.accentSoft),
      accentLine: m(accentLine, other.accentLine),
      bg: m(bg, other.bg),
      surface: m(surface, other.surface),
      surfaceMuted: m(surfaceMuted, other.surfaceMuted),
      border: m(border, other.border),
      textPrimary: m(textPrimary, other.textPrimary),
      textSecondary: m(textSecondary, other.textSecondary),
      textFaint: m(textFaint, other.textFaint),
      railBg: m(railBg, other.railBg),
      railText: m(railText, other.railText),
      railMuted: m(railMuted, other.railMuted),
      railFaint: m(railFaint, other.railFaint),
      railActive: m(railActive, other.railActive),
      railBorder: m(railBorder, other.railBorder),
      success: m(success, other.success),
      warning: m(warning, other.warning),
      danger: m(danger, other.danger),
      tagBg: m(tagBg, other.tagBg),
      tagText: m(tagText, other.tagText),
      chart1: m(chart1, other.chart1),
      chart2: m(chart2, other.chart2),
      chart3: m(chart3, other.chart3),
      chart4: m(chart4, other.chart4),
      chart5: m(chart5, other.chart5),
      codeEditorBg: m(codeEditorBg, other.codeEditorBg),
      codeLogBg: m(codeLogBg, other.codeLogBg),
      codeText: m(codeText, other.codeText),
    );
  }
}

/// 토큰 접근 단축: `context.dpColors.primaryText`.
/// 확장은 노출 타입(DpColors)과 같은 파일에 두어, DpColors를 쓰는 위젯이
/// 별도 import 없이 토큰에 접근하도록 한다.
extension DpColorsX on BuildContext {
  DpColors get dpColors => Theme.of(this).extension<DpColors>()!;
}
