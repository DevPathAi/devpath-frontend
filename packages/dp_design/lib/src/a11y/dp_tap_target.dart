import 'package:flutter/material.dart';

/// 최소 44x44 탭 타깃 + 시맨틱 라벨 보장(DESIGN §6 / DD7).
class DpTapTarget extends StatelessWidget {
  const DpTapTarget({
    super.key,
    required this.child,
    required this.onTap,
    required this.semanticLabel,
    this.minSize = 44,
  });

  final Widget child;
  final VoidCallback onTap;
  final String semanticLabel;
  final double minSize;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: InkResponse(
        onTap: onTap,
        radius: minSize / 2,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: minSize, minHeight: minSize),
          child: Center(child: child),
        ),
      ),
    );
  }
}
