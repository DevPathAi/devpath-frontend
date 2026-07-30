import 'package:flutter/widgets.dart';

/// Material 3 window size class(DESIGN.md §5). 폭 경계는 SSoT — 재정의 금지.
enum DpWindowClass { compact, medium, expanded, large }

DpWindowClass dpWindowClassOf(double width) {
  if (width < 600) return DpWindowClass.compact;
  if (width < 840) return DpWindowClass.medium;
  if (width < 1240) return DpWindowClass.expanded;
  return DpWindowClass.large;
}

/// 현재 컨텍스트 폭의 size class 조회.
extension DpWindowClassX on BuildContext {
  DpWindowClass get windowClass =>
      dpWindowClassOf(MediaQuery.sizeOf(this).width);
}
