import 'package:flutter/material.dart';

/// 본문 텍스트를 브라우저처럼 선택 가능하게 만든다(웹 완성도).
/// 버튼·내비 등 비선택 영역은 감싸지 않는다.
class DpSelectable extends StatelessWidget {
  const DpSelectable({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => SelectionArea(child: child);
}
