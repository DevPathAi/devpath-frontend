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
}
