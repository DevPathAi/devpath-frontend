import 'package:flutter/material.dart';

import '../theme/dp_colors.dart';
import '../theme/dp_tokens.dart';

/// 클릭 가능한 커스텀 카드의 웹 표준 베이스.
/// FocusableActionDetector(hover+focus+키보드) → Material(투명) → InkWell(리플).
/// GestureDetector 단독 사용을 대체한다(키보드 사용자 접근 보장).
class DpInteractiveCard extends StatefulWidget {
  const DpInteractiveCard({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final VoidCallback? onTap;
  final double? borderRadius;
  final EdgeInsetsGeometry padding;

  @override
  State<DpInteractiveCard> createState() => _DpInteractiveCardState();
}

class _DpInteractiveCardState extends State<DpInteractiveCard> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final c = context.dpColors;
    final radius = BorderRadius.circular(
      widget.borderRadius ?? context.appTokens.panelRadius,
    );

    final Color borderColor;
    final double borderWidth;
    if (_focused) {
      borderColor = c.primaryText;
      borderWidth = 2;
    } else if (_hovered) {
      borderColor = c.primary;
      borderWidth = 1;
    } else {
      borderColor = c.border;
      borderWidth = 1;
    }

    return FocusableActionDetector(
      enabled: widget.onTap != null,
      mouseCursor: widget.onTap != null
          ? SystemMouseCursors.click
          : MouseCursor.defer,
      onShowHoverHighlight: (v) => setState(() => _hovered = v),
      onShowFocusHighlight: (v) => setState(() => _focused = v),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: radius,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: borderColor, width: borderWidth),
            ),
            child: Padding(padding: widget.padding, child: widget.child),
          ),
        ),
      ),
    );
  }
}
