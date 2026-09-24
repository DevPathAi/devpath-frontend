import 'package:flutter/material.dart';

/// 레이아웃 토큰(폭·반경·헤더 높이). DESIGN.md §3·§5 + 스펙 2026-09-19 §5.3.
/// 색과 달리 밝기 무관 — light/dark 모두 [standard] 단일값을 쓴다.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.contentMaxWidth,
    required this.readableMaxWidth,
    required this.railWidth,
    required this.railCollapsedWidth,
    required this.panelRadius,
    required this.headerHeight,
  });

  final double contentMaxWidth;
  final double readableMaxWidth;

  /// admin 의 DpAppShell/DpNavRail 이 쓴다. web 셸은 P2 에서 헤더로 바뀐다.
  final double railWidth;
  final double railCollapsedWidth;
  final double panelRadius;

  /// 상단 헤더 높이(시안 `.hd` 56px). P2 의 DpWebShell 이 소비한다.
  final double headerHeight;

  static const standard = AppTokens(
    contentMaxWidth: 1120,
    readableMaxWidth: 760,
    railWidth: 280,
    railCollapsedWidth: 80,
    panelRadius: 8, // = DpRadius.card
    headerHeight: 56,
  );

  @override
  AppTokens copyWith({
    double? contentMaxWidth,
    double? readableMaxWidth,
    double? railWidth,
    double? railCollapsedWidth,
    double? panelRadius,
    double? headerHeight,
  }) => AppTokens(
    contentMaxWidth: contentMaxWidth ?? this.contentMaxWidth,
    readableMaxWidth: readableMaxWidth ?? this.readableMaxWidth,
    railWidth: railWidth ?? this.railWidth,
    railCollapsedWidth: railCollapsedWidth ?? this.railCollapsedWidth,
    panelRadius: panelRadius ?? this.panelRadius,
    headerHeight: headerHeight ?? this.headerHeight,
  );

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    return AppTokens(
      contentMaxWidth: _lerp(contentMaxWidth, other.contentMaxWidth, t),
      readableMaxWidth: _lerp(readableMaxWidth, other.readableMaxWidth, t),
      railWidth: _lerp(railWidth, other.railWidth, t),
      railCollapsedWidth: _lerp(
        railCollapsedWidth,
        other.railCollapsedWidth,
        t,
      ),
      panelRadius: _lerp(panelRadius, other.panelRadius, t),
      headerHeight: _lerp(headerHeight, other.headerHeight, t),
    );
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;
}

/// 토큰 접근 단축: `context.appTokens.contentMaxWidth`.
extension AppTokensX on BuildContext {
  AppTokens get appTokens => Theme.of(this).extension<AppTokens>()!;
}
