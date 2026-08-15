import 'package:flutter/widgets.dart';

/// 간격(8pt 그리드)·라운드·모션. DESIGN.md §3·§7.
abstract final class DpSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
}

abstract final class DpRadius {
  static const double chip = 12;
  static const double button = 8;
  static const double card = 10;
  static const double input = 8;
  static const double dialog = 12;
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
