import 'package:flutter/material.dart';

import 'dp_colors.dart';

/// 상호작용 6상태(normal/hover/focus/pressed/selected/disabled) 스타일 팩토리.
/// 색은 DpColors 토큰만 사용(로드맵 §4.2). 색만으로 의미 전달 금지 —
/// 소비 위젯은 selected에 굵기/테두리를 병행한다.
abstract final class DpStateStyle {
  /// 내비게이션 항목·리스트 행 배경 오버레이.
  static WidgetStateProperty<Color> navItemBackground(DpColors c) =>
      WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return Colors.transparent;
        if (states.contains(WidgetState.selected)) {
          return c.primary.withValues(alpha: 0.12);
        }
        if (states.contains(WidgetState.pressed)) return c.border;
        if (states.contains(WidgetState.hovered)) return c.bg;
        return Colors.transparent;
      });
}
