import 'package:flutter/material.dart';

import '../theme/dp_spacing.dart';

/// 최소 포인터 타깃(기본 24 = DpDensity.minTarget, WCAG 2.2 AA 2.5.8) + 시맨틱 라벨 보장(DESIGN §6).
/// 24 미만이 될 수 없고, 더 큰 값이 필요하면 minSize 로 올린다.
class DpTapTarget extends StatelessWidget {
  const DpTapTarget({
    super.key,
    required this.child,
    required this.onTap,
    required this.semanticLabel,
    this.minSize = DpDensity.minTarget,
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
