import 'package:flutter/material.dart';

/// 웹/데스크톱 스크롤바를 항상 표시(특히 가로 스크롤 탐색성).
/// 스크롤 영역과 동일한 [controller]를 반드시 공유한다.
class DpScrollbar extends StatelessWidget {
  const DpScrollbar({
    super.key,
    required this.controller,
    required this.child,
  });

  final ScrollController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) => Scrollbar(
    controller: controller,
    thumbVisibility: true,
    interactive: true,
    child: child,
  );
}
