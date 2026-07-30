import 'package:dp_design/src/theme/dp_colors.dart';
import 'package:dp_design/src/theme/dp_state_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final p = DpStateStyle.navItemBackground(DpColors.light);

  test('selected는 primary 12% 오버레이', () {
    expect(
      p.resolve({WidgetState.selected}),
      DpColors.light.primary.withValues(alpha: 0.12),
    );
  });

  test('hovered는 bg', () {
    expect(p.resolve({WidgetState.hovered}), DpColors.light.bg);
  });

  test('pressed는 border', () {
    expect(p.resolve({WidgetState.pressed}), DpColors.light.border);
  });

  test('기본(무상태)은 투명', () {
    expect(p.resolve(<WidgetState>{}), Colors.transparent);
  });

  test('disabled는 selected보다 우선하여 투명', () {
    expect(
      p.resolve({WidgetState.disabled, WidgetState.selected}),
      Colors.transparent,
    );
  });
}
