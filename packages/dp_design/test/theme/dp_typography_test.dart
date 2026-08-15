import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('본문 폰트는 Pretendard, 한글 행간 1.6', () {
    final t = DpTypography.textTheme(Brightness.light);
    expect(t.bodyLarge!.fontFamily, 'Pretendard');
    expect(t.bodyLarge!.fontSize, 16);
    expect(t.bodyLarge!.height, closeTo(1.6, 0.001));
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
        t.bodyLarge,
        t.bodyMedium,
        t.bodySmall,
        t.labelLarge,
        t.labelMedium,
        t.labelSmall,
      ]) {
        expect(s!.fontFamily, 'Pretendard');
      }
    });
  });

  group('labelSmall 추가', () {
    final t = DpTypography.textTheme(Brightness.light);

    test('정의돼 있다 — ad_slot_widget·path_plan_view 태그가 참조한다', () {
      // 미정의 시 Material 기본 labelSmall(11/16, w400)이 쓰여 한글 행간이
      // 적용되지 않는다. titleLarge/titleSmall/labelMedium을 추가한 것과
      // 같은 근거로 labelSmall도 명시 정의한다.
      expect(t.labelSmall, isNotNull);
    });

    test('DESIGN.md 근거 스케일과 일치한다 — 11/16, w500', () {
      expect(t.labelSmall!.fontSize, 11);
      expect(t.labelSmall!.fontWeight, FontWeight.w500);
      expect(t.labelSmall!.height, closeTo(16 / 11, 0.001));
    });
  });
}
