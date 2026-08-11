import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 차트 팔레트 값 계약. **여기만 리터럴 hex를 쓴다** — 값 자체가 계약이기 때문이다.
/// (다른 테스트는 토큰을 참조한다. 둘의 역할이 다르다.)
///
/// 판정 근거는 `docs/superpowers/specs/2026-08-07-chart-palette-check.py`가 갖고,
/// 이 테스트는 스크립트가 검사한 그 값이 코드에 실제로 들어왔는지를 잠근다.
void main() {
  test('라이트 차트 계열 색이 스펙 값과 일치한다', () {
    expect(DpColors.light.chart1, const Color(0xFF1D4ED8));
    expect(DpColors.light.chart2, const Color(0xFFBE185D));
    expect(DpColors.light.chart3, const Color(0xFF7E22CE));
    expect(DpColors.light.chart4, const Color(0xFF0F766E)); // 보조색 — 불변
  });

  test('다크 차트 계열 색이 스펙 값과 일치한다', () {
    expect(DpColors.dark.chart1, const Color(0xFF60A5FA));
    expect(DpColors.dark.chart2, const Color(0xFFF472B6));
    expect(DpColors.dark.chart3, const Color(0xFFD8B4FE));
    expect(DpColors.dark.chart4, const Color(0xFF2DD4BF)); // 보조색 — 불변
  });

  test('계열 색이 브랜드·의미 토큰과 겹치지 않는다', () {
    // 3-A에서 chart1 == primary 중복이 「이관해도 픽셀 변화 0」을 만들었다.
    // 같은 사고를 값 수준에서 막는다.
    for (final c in [DpColors.light, DpColors.dark]) {
      for (final series in [c.chart1, c.chart2, c.chart3]) {
        expect(series, isNot(c.primary));
        expect(series, isNot(c.success));
        expect(series, isNot(c.warning));
        expect(series, isNot(c.danger));
        expect(series, isNot(c.chart4));
        expect(series, isNot(c.chart5)); // 스펙 초안이 빠뜨린 실재 토큰
      }
    }
  });
}
