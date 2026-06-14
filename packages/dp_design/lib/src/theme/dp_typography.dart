import 'package:flutter/material.dart';

/// DESIGN.md §2 타입 스케일. 본문 Pretendard(한글 행간 1.6), 코드 D2Coding.
abstract final class DpTypography {
  static const String family = 'Pretendard';
  static const String codeFamily = 'D2Coding';

  /// 코드/고정폭 텍스트 기본 스타일.
  static const TextStyle code = TextStyle(fontFamily: codeFamily, height: 1.5);

  static TextTheme textTheme(Brightness brightness) {
    const f = family;
    return const TextTheme(
      displaySmall: TextStyle(fontFamily: f, fontSize: 36, height: 44 / 36),
      headlineSmall: TextStyle(
        fontFamily: f,
        fontSize: 24,
        height: 32 / 24,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: TextStyle(
        fontFamily: f,
        fontSize: 16,
        height: 24 / 16,
        fontWeight: FontWeight.w600,
      ),
      bodyMedium: TextStyle(fontFamily: f, fontSize: 14, height: 1.6),
      bodySmall: TextStyle(fontFamily: f, fontSize: 13, height: 20 / 13),
      labelLarge: TextStyle(
        fontFamily: f,
        fontSize: 14,
        height: 20 / 14,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
