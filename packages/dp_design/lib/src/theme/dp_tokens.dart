import 'package:flutter/material.dart';

/// 레이아웃 토큰(폭·반경). DESIGN.md §3·§5 + 로드맵 §4.1.
/// 색과 달리 밝기 무관 — light/dark 모두 [standard] 단일값을 쓴다.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.contentMaxWidth,
    required this.readableMaxWidth,
    required this.railWidth,
    required this.railCollapsedWidth,
    required this.panelRadius,
  });

  final double contentMaxWidth;
  final double readableMaxWidth;
  final double railWidth;
  final double railCollapsedWidth;
  final double panelRadius;

  static const standard = AppTokens(
    contentMaxWidth: 1440,
    readableMaxWidth: 880,
    railWidth: 256,
    railCollapsedWidth: 72,
    panelRadius: 10, // = DpRadius.card
  );

  @override
  AppTokens copyWith({
    double? contentMaxWidth,
    double? readableMaxWidth,
    double? railWidth,
    double? railCollapsedWidth,
    double? panelRadius,
  }) => AppTokens(
    contentMaxWidth: contentMaxWidth ?? this.contentMaxWidth,
    readableMaxWidth: readableMaxWidth ?? this.readableMaxWidth,
    railWidth: railWidth ?? this.railWidth,
    railCollapsedWidth: railCollapsedWidth ?? this.railCollapsedWidth,
    panelRadius: panelRadius ?? this.panelRadius,
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
    );
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;
}

/// 토큰 접근 단축: `context.appTokens.contentMaxWidth`.
extension AppTokensX on BuildContext {
  AppTokens get appTokens => Theme.of(this).extension<AppTokens>()!;
}
