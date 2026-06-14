import 'package:dp_design/src/theme/dp_typography.dart';
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
}
