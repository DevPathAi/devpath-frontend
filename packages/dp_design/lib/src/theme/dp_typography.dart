import 'package:flutter/material.dart';

/// DESIGN.md §2 타입 스케일. 본문 Pretendard(한글 행간 1.6), 코드 D2Coding.
abstract final class DpTypography {
  static const String family = 'packages/dp_design/Pretendard';
  static const String codeFamily = 'packages/dp_design/D2Coding';

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
        fontSize: 28,
        height: 36 / 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      titleLarge: TextStyle(
        fontFamily: f,
        fontSize: 22,
        height: 30 / 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.25,
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

/// 시안의 보조 문구 스타일을 **토큰 계약에서 파생**해 쓴다.
///
/// [DpTypography.textTheme] 의 슬롯은 시맨틱 토큰 계약 2.0.0 의 CSS 투영 대상이라
/// 버전 없이 값을 바꿀 수 없다. 그리고 시안의 `.meta`(12px)·`.ex`(13px)·
/// `.steps li`(13px) 는 `font-size` 만 덮고 `line-height` 는 `body{line-height:1.6}`
/// 을 그대로 물려받는다 — 즉 슬롯을 고르는 문제가 아니라 **본문 스타일에서 크기만
/// 줄이는** 문제다. 여기서 파생하면 계약을 건드리지 않고 시안과 1:1 로 대조할 수 있고,
/// 화면마다 `TextStyle(fontSize: 12)` 리터럴이 흩어지는 것도 막는다.
extension DpDerivedTextX on BuildContext {
  /// 시안 `.meta` — 12px 보조 문구. 행간은 본문(1.6)을 잇는다.
  ///
  /// 한 줄 상태·태그·표 머리는 `labelMedium`(12 / 16)이고 **이것과 다르다.**
  /// 시안에서 `.st`·`.tag`·`th` 는 `white-space:nowrap` 이거나 한 줄이라 행간이
  /// 드러나지 않지만, 여러 줄로 흐르는 보조 문구는 드러난다.
  TextStyle get dpMeta => dpBody(12);

  /// 본문 토큰에서 크기만 바꾼 스타일. 시안이 `font-size` 만 덮는 자리에 쓴다.
  TextStyle dpBody(double fontSize) =>
      Theme.of(this).textTheme.bodyMedium!.copyWith(fontSize: fontSize);
}
