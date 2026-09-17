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
      // 포커스 노드는 이 detector 하나만 갖는다. 안쪽 InkWell 이 자기 노드를 더 만들면
      // 카드마다 Tab 정지가 두 번 생긴다(브라우저 실측). Enter/Space 활성화는 여기서 받는다.
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onTap?.call();
            return null;
          },
        ),
      },
      mouseCursor: widget.onTap != null
          ? SystemMouseCursors.click
          : MouseCursor.defer,
      onShowHoverHighlight: (v) => setState(() => _hovered = v),
      onShowFocusHighlight: (v) => setState(() => _focused = v),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          canRequestFocus: false,
          borderRadius: radius,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: _hovered
                  ? c.accentSoft.withValues(alpha: 0.45)
                  : c.surface,
              borderRadius: radius,
              border: Border.all(color: borderColor, width: borderWidth),
              boxShadow: _hovered
                  ? [
                      BoxShadow(
                        color: c.textPrimary.withValues(alpha: 0.07),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            child: Padding(padding: widget.padding, child: widget.child),
          ),
        ),
      ),
    );
  }
}
