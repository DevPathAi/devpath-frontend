import 'dart:math' as math;
import 'dart:ui';

import 'package:dp_design/dp_design.dart';
import 'package:flutter_test/flutter_test.dart';

/// WCAG 상대 휘도.
double _lum(Color c) {
  double ch(double v) =>
      v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

double contrast(Color a, Color b) {
  final la = _lum(a), lb = _lum(b);
  final hi = math.max(la, lb), lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  // 스펙 §8: 17조합 × 라이트·다크 = 34건. 미달 0건이 확인된 값이다.
  // 토큰 값을 바꿀 때 이 테스트가 회귀를 막는다.
  for (final (label, p) in [('라이트', DpColors.light), ('다크', DpColors.dark)]) {
    group('$label 대비', () {
      test('본문 텍스트는 4.5:1 이상', () {
        expect(contrast(p.textPrimary, p.bg), greaterThanOrEqualTo(4.5));
        expect(contrast(p.textPrimary, p.surface), greaterThanOrEqualTo(4.5));
        expect(contrast(p.textSecondary, p.bg), greaterThanOrEqualTo(4.5));
        expect(contrast(p.textSecondary, p.surface), greaterThanOrEqualTo(4.5));
      });

      test('강조 텍스트는 4.5:1, strong 은 7:1 이상', () {
        expect(contrast(p.primaryText, p.bg), greaterThanOrEqualTo(4.5));
        expect(contrast(p.primaryText, p.surface), greaterThanOrEqualTo(4.5));
        expect(contrast(p.primaryTextStrong, p.surface), greaterThanOrEqualTo(7.0));
        expect(contrast(p.primaryText, p.accentSoft), greaterThanOrEqualTo(4.5));
      });

      test('★채움 위 텍스트 4.5:1 — 다크는 onPrimary 가 어두운 색이다', () {
        // 앰버(#F59E0B) 위 흰 텍스트는 2.2:1 로 미달한다. 다크의 onPrimary 는
        // #1A1200 이며 라이트(#FFFFFF)와 방향이 반대다. 이 단언이 그 반전을 지킨다.
        expect(contrast(p.onPrimary, p.primary), greaterThanOrEqualTo(4.5));
      });

      test('시맨틱 색은 surface 위 4.5:1 이상', () {
        expect(contrast(p.success, p.surface), greaterThanOrEqualTo(4.5));
        expect(contrast(p.warning, p.surface), greaterThanOrEqualTo(4.5));
        expect(contrast(p.danger, p.surface), greaterThanOrEqualTo(4.5));
      });

      test('사이드바 대비 — 활성 4.5:1 · 섹션 레이블 3:1', () {
        expect(contrast(p.railText, p.railBg), greaterThanOrEqualTo(4.5));
        expect(contrast(p.railMuted, p.railBg), greaterThanOrEqualTo(4.5));
        expect(contrast(p.railFaint, p.railBg), greaterThanOrEqualTo(3.0));
      });

      test('faint·태그', () {
        // textFaint 는 UI 컴포넌트 기준 3:1 이며 본문 텍스트로 쓰지 않는다.
        expect(contrast(p.textFaint, p.bg), greaterThanOrEqualTo(3.0));
        expect(contrast(p.tagText, p.tagBg), greaterThanOrEqualTo(4.5));
      });
    });
  }
}
