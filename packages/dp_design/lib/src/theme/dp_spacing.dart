import 'package:flutter/widgets.dart';

/// 간격(8pt 그리드)·라운드·밀도·모션. DESIGN.md §3·§6·§7.
abstract final class DpSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
}

/// 반경 — 웹 문법(계약 2.0.0, 스펙 2026-09-19 §5.3 + 시안 `--r-chip/--r-btn/--r-card`).
/// 칩·태그 4, 버튼·입력 6, 카드·패널·드롭다운 8, 다이얼로그·시트 12.
abstract final class DpRadius {
  static const double chip = 4;
  static const double button = 6;
  static const double card = 8;
  static const double input = 6;
  static const double dialog = 12;
}

/// 포인터 밀도(계약 2.0.0, 스펙 2026-09-19 §5.4-1 — 사용자 결정 "촘촘").
/// 컨트롤(버튼·입력·세그먼트·헤더 항목) 높이 30, 표 행 세로 여백 8,
/// 최소 포인터 타깃 24 = WCAG 2.2 AA 2.5.8. 24 미만인 타깃은 인접 타깃과의
/// 간격으로 예외 조건을 만족시켜야 한다(browser-ux 러너 `MIN_TARGET` 과 같은 값).
abstract final class DpDensity {
  static const double controlHeight = 30;
  static const double rowPadding = 8;
  static const double minTarget = 24;
}

abstract final class DpDurations {
  static const Duration stageReveal = Duration(milliseconds: 200);
  static const Duration skeletonCrossfade = Duration(milliseconds: 150);
  // 로드맵 §4.3 — hover/select/panelExpand (과도한 지연 회피).
  static const Duration hover = Duration(milliseconds: 120);
  static const Duration select = Duration(milliseconds: 180);
  static const Duration panelExpand = Duration(milliseconds: 220);
}

/// 플랫폼의 reduced-motion 설정을 모든 디자인 프리미티브가 같은 방식으로
/// 적용하도록 하는 단일 해석 지점.
abstract final class DpMotion {
  static Duration resolve(BuildContext context, Duration duration) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return reduceMotion ? Duration.zero : duration;
  }
}
