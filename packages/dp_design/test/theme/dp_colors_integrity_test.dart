import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// DpColors 의 32필드 전부에 대한 접근자. 새 필드를 추가하면 여기도 늘려야
/// lerp(t=1) 단언이 그 필드까지 덮는다(누락 시 컴파일 에러는 나지 않으므로
/// 사람이 챙겨야 한다 — dp_colors.dart 클래스 docstring 참고).
final Map<String, Color Function(DpColors)> _allFields = {
  'primary': (c) => c.primary,
  'primaryText': (c) => c.primaryText,
  'primaryTextStrong': (c) => c.primaryTextStrong,
  'onPrimary': (c) => c.onPrimary,
  'accentSoft': (c) => c.accentSoft,
  'accentLine': (c) => c.accentLine,
  'bg': (c) => c.bg,
  'surface': (c) => c.surface,
  'surfaceMuted': (c) => c.surfaceMuted,
  'border': (c) => c.border,
  'textPrimary': (c) => c.textPrimary,
  'textSecondary': (c) => c.textSecondary,
  'textFaint': (c) => c.textFaint,
  'headerBg': (c) => c.headerBg,
  'headerText': (c) => c.headerText,
  'headerMuted': (c) => c.headerMuted,
  'headerFaint': (c) => c.headerFaint,
  'headerActive': (c) => c.headerActive,
  'headerBorder': (c) => c.headerBorder,
  'success': (c) => c.success,
  'warning': (c) => c.warning,
  'danger': (c) => c.danger,
  'tagBg': (c) => c.tagBg,
  'tagText': (c) => c.tagText,
  'chart1': (c) => c.chart1,
  'chart2': (c) => c.chart2,
  'chart3': (c) => c.chart3,
  'chart4': (c) => c.chart4,
  'chart5': (c) => c.chart5,
  'codeEditorBg': (c) => c.codeEditorBg,
  'codeLogBg': (c) => c.codeLogBg,
  'codeText': (c) => c.codeText,
};

void main() {
  // ThemeExtension 은 필드·copyWith·lerp 셋이 일치해야 한다.
  // 하나라도 빠지면 테마 전환 애니메이션에서 그 토큰만 튄다.
  test('필드 접근자 맵은 32개 전부를 덮는다(회귀 방지)', () {
    expect(_allFields.length, 32);
  });

  test('lerp(t=1) 은 32필드 전부 목적지 값과 같다', () {
    // 필드를 하나씩 나열하는 대신 라이트·다크 각 팔레트의 필드별 값을 순회한다.
    // 10개(구판)만 단언했을 때는 미단언 22개 사이의 오배선
    // (예: chart3: m(chart2, other.chart2) 같은 복붙 실수)이 통과했다.
    final mid = DpColors.light.lerp(DpColors.dark, 1.0);
    for (final entry in _allFields.entries) {
      expect(entry.value(mid), entry.value(DpColors.dark), reason: entry.key);
    }
  });

  test('lerp(t=0) 은 출발 토큰을 그대로 돌려준다', () {
    final mid = DpColors.light.lerp(DpColors.dark, 0.0);
    expect(mid.headerFaint, DpColors.light.headerFaint);
    expect(mid.chart4, DpColors.light.chart4);
  });

  test('copyWith 는 지정한 토큰만 바꾼다', () {
    final c = DpColors.light.copyWith(chart4: const Color(0xFF123456));
    expect(c.chart4, const Color(0xFF123456));
    expect(c.chart1, DpColors.light.chart1);
    expect(c.headerBg, DpColors.light.headerBg);
    expect(c.surfaceMuted, DpColors.light.surfaceMuted);
  });

  test('Leva v2 팔레트 기준값 — 인디고와 푸른 무채색', () {
    expect(DpColors.light.bg, const Color(0xFFF6F7FB));
    expect(DpColors.light.primary, const Color(0xFF5653E7));
    expect(DpColors.light.headerBg, const Color(0xFF11131B));
    expect(DpColors.dark.onPrimary, const Color(0xFF17163D));
  });

  test('header* 는 rail* 의 값을 그대로 승계한다(계약 2.0.0 이름 변경, 값 불변)', () {
    expect(DpColors.light.headerBg, const Color(0xFF11131B));
    expect(DpColors.light.headerText, const Color(0xFFF5F7FB));
    expect(DpColors.light.headerMuted, const Color(0xFFB7BDCA));
    expect(DpColors.light.headerFaint, const Color(0xFF959DAD));
    expect(DpColors.light.headerActive, const Color(0xFF272B3F));
    expect(DpColors.light.headerBorder, const Color(0xFF2A2F3C));
    expect(DpColors.dark.headerBg, const Color(0xFF090B10));
    expect(DpColors.dark.headerText, const Color(0xFFF4F5F8));
    expect(DpColors.dark.headerMuted, const Color(0xFFB6BCC8));
    expect(DpColors.dark.headerFaint, const Color(0xFF929AA8));
    expect(DpColors.dark.headerActive, const Color(0xFF23263B));
    expect(DpColors.dark.headerBorder, const Color(0xFF292D38));
  });
}
