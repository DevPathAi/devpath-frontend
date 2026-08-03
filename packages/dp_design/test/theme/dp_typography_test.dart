import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('본문 폰트는 Pretendard, 한글 행간 1.6', () {
    final t = DpTypography.textTheme(Brightness.light);
    expect(t.bodyMedium!.fontFamily, 'Pretendard');
    expect(t.bodyMedium!.height, closeTo(1.6, 0.001));
    expect(t.titleMedium!.fontWeight, FontWeight.w600);
  });

  test('코드용 폰트 헬퍼는 D2Coding', () {
    expect(DpTypography.code.fontFamily, 'D2Coding');
  });

  group('타입 스케일 추가 3종', () {
    final t = DpTypography.textTheme(Brightness.light);

    test('추가 3종이 정의돼 있다 — 미정의면 Material 기본 크기·행간이 쓰인다', () {
      // 실측: titleLarge 1곳 · titleSmall 4곳 · labelMedium 2곳이 이미 사용 중이었고,
      // 정의가 없어 한글 행간(1.6)이 적용되지 않았다.
      expect(t.titleLarge, isNotNull);
      expect(t.titleSmall, isNotNull);
      expect(t.labelMedium, isNotNull);
    });

    test('DESIGN.md §2 스케일과 일치한다', () {
      expect(t.titleLarge!.fontSize, 20);
      expect(t.titleLarge!.fontWeight, FontWeight.w700);
      expect(t.titleSmall!.fontSize, 14);
      expect(t.titleSmall!.fontWeight, FontWeight.w600);
      expect(t.labelMedium!.fontSize, 12);
      expect(t.labelMedium!.fontWeight, FontWeight.w600);
    });

    test('모든 정의 스타일이 Pretendard 를 쓴다', () {
      for (final s in [
        t.displaySmall,
        t.headlineSmall,
        t.titleLarge,
        t.titleMedium,
        t.titleSmall,
        t.bodyMedium,
        t.bodySmall,
        t.labelLarge,
        t.labelMedium,
      ]) {
        expect(s!.fontFamily, 'Pretendard');
      }
    });
  });
}
