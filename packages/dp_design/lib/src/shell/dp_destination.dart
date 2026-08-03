import 'package:flutter/widgets.dart';

/// 앱 셸 목적지(표현부 계약). 라우팅 비의존 — 경로 해석은 앱이 index로 처리.
///
/// [section]이 있으면 레일에서 그룹 레이블로 묶인다. **중첩 리스트가 아니라
/// 평면 리스트에서 연속된 같은 [section]끼리 묶는 방식**이라 selectedIndex
/// 계산이 단순하게 유지된다. null이면 그룹 없음(admin).
/// [badgeCount] 0 = 배지 없음.
@immutable
class DpDestination {
  const DpDestination({
    required this.icon,
    required this.label,
    this.section,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String label;
  final String? section;
  final int badgeCount;
}
