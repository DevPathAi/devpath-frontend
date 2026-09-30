import 'package:flutter/foundation.dart';

/// 상단 헤더의 주 메뉴 항목. [children] 이 비어 있지 않으면 드롭다운이다.
///
/// [id] 는 dp_design 에게 불투명한 문자열이다 — 앱이 경로로 해석한다
/// (`DpDestination` 의 index 방식과 다른 판단: 커뮤니티 자식까지 index 로
/// 세면 앱이 평면·계층 두 벌의 순서를 맞춰야 한다).
@immutable
class DpWebNavItem {
  const DpWebNavItem({
    required this.id,
    required this.label,
    this.children = const [],
  });

  final String id;
  final String label;
  final List<DpWebNavItem> children;

  /// 이 항목이나 그 자식이 [selectedId] 인가.
  bool isCurrent(String? selectedId) =>
      selectedId != null &&
      (id == selectedId || children.any((child) => child.id == selectedId));
}
