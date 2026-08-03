import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ThemeExtension 은 필드·copyWith·lerp 셋이 일치해야 한다.
  // 하나라도 빠지면 테마 전환 애니메이션에서 그 토큰만 튄다.
  test('lerp(t=1) 은 목적지 토큰을 그대로 돌려준다', () {
    final mid = DpColors.light.lerp(DpColors.dark, 1.0) as DpColors;
    expect(mid.bg, DpColors.dark.bg);
    expect(mid.surfaceMuted, DpColors.dark.surfaceMuted);
    expect(mid.railBg, DpColors.dark.railBg);
    expect(mid.railActive, DpColors.dark.railActive);
    expect(mid.textFaint, DpColors.dark.textFaint);
    expect(mid.accentSoft, DpColors.dark.accentSoft);
    expect(mid.accentLine, DpColors.dark.accentLine);
    expect(mid.tagBg, DpColors.dark.tagBg);
    expect(mid.chart1, DpColors.dark.chart1);
    expect(mid.chart5, DpColors.dark.chart5);
  });

  test('lerp(t=0) 은 출발 토큰을 그대로 돌려준다', () {
    final mid = DpColors.light.lerp(DpColors.dark, 0.0) as DpColors;
    expect(mid.railFaint, DpColors.light.railFaint);
    expect(mid.chart4, DpColors.light.chart4);
  });

  test('copyWith 는 지정한 토큰만 바꾼다', () {
    final c = DpColors.light.copyWith(chart4: const Color(0xFF123456));
    expect(c.chart4, const Color(0xFF123456));
    expect(c.chart1, DpColors.light.chart1);
    expect(c.railBg, DpColors.light.railBg);
    expect(c.surfaceMuted, DpColors.light.surfaceMuted);
  });

  test('T2 팔레트 기준값 — 라이트 배경은 따뜻한 무채색', () {
    expect(DpColors.light.bg, const Color(0xFFFAF9F7));
    expect(DpColors.light.primary, const Color(0xFFB45309));
    expect(DpColors.light.railBg, const Color(0xFF1A1815));
    // 다크의 onPrimary 는 어두운 색이다(라이트와 반대).
    expect(DpColors.dark.onPrimary, const Color(0xFF1A1200));
  });
}
