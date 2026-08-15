import 'package:flutter/material.dart';

/// DESIGN.md §2 타입 스케일. 본문 Pretendard(한글 행간 1.6), 코드 D2Coding.
abstract final class DpTypography {
  static const String family = 'Pretendard';
  static const String codeFamily = 'D2Coding';

  /// 코드/고정폭 텍스트 기본 스타일.
  static const TextStyle code = TextStyle(
    fontFamily: codeFamily,
    fontSize: 14,
    height: 1.5,
  );

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
      titleLarge: TextStyle(
        fontFamily: f,
        fontSize: 20,
        height: 28 / 20,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: TextStyle(
        fontFamily: f,
        fontSize: 16,
        height: 24 / 16,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: TextStyle(
        fontFamily: f,
        fontSize: 14,
        height: 20 / 14,
        fontWeight: FontWeight.w600,
      ),
      // 학습 본문은 Mission Ledger 계약의 16–18px 범위를 지킨다.
      // 짧은 UI 설명은 bodyMedium, 읽기 본문은 bodyLarge를 사용한다.
      bodyLarge: TextStyle(fontFamily: f, fontSize: 16, height: 1.6),
      bodyMedium: TextStyle(fontFamily: f, fontSize: 14, height: 1.6),
      bodySmall: TextStyle(fontFamily: f, fontSize: 13, height: 20 / 13),
      labelLarge: TextStyle(
        fontFamily: f,
        fontSize: 14,
        height: 20 / 14,
        fontWeight: FontWeight.w600,
      ),
      labelMedium: TextStyle(
        fontFamily: f,
        fontSize: 12,
        height: 16 / 12,
        fontWeight: FontWeight.w600,
      ),
      labelSmall: TextStyle(
        fontFamily: f,
        fontSize: 11,
        height: 16 / 11,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
