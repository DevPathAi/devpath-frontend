import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/dp_colors.dart';
import '../theme/dp_spacing.dart';
import '../theme/dp_tokens.dart';

enum DpNextActionBandVariant { inline, stickySafe }

enum DpNextActionState { ready, pending, disabled, retry, completed }

/// 화면의 하나뿐인 primary action과 그 결과를 관계 지어 표시한다.
/// action 계산/navigation/mutation/analytics는 feature 계층의 책임이다.
class DpNextActionBand extends StatefulWidget {
  const DpNextActionBand({
    super.key,
    required this.actionId,
    required this.label,
    required this.expectedOutcome,
    required this.state,
    this.variant = DpNextActionBandVariant.inline,
    this.pendingLabel,
    this.disabledReason,
    this.retryLabel = '다시 시도',
    this.onPressed,
    this.focusNode,
    this.subordinateActionId,
    this.subordinateLabel,
    this.onSubordinatePressed,
  }) : assert(
         (subordinateActionId == null && subordinateLabel == null) ||
             (subordinateActionId != null && subordinateLabel != null),
       ),
       assert(
         (state != DpNextActionState.ready &&
                 state != DpNextActionState.retry) ||
             onPressed != null,
         'ready/retry actions require an intent callback.',
       ),
       assert(
         state != DpNextActionState.disabled ||
             (disabledReason != null && disabledReason != ''),
         'disabled actions require a visible reason.',
       );

  final String actionId;
  final String label;
  final String expectedOutcome;
  final DpNextActionState state;
  final DpNextActionBandVariant variant;
  final String? pendingLabel;
  final String? disabledReason;
  final String retryLabel;
  final ValueChanged<String>? onPressed;
  final FocusNode? focusNode;
  final String? subordinateActionId;
  final String? subordinateLabel;
  final ValueChanged<String>? onSubordinatePressed;

  @override
  State<DpNextActionBand> createState() => _DpNextActionBandState();
}

class _DpNextActionBandState extends State<DpNextActionBand> {
  bool _focused = false;
  bool _hovered = false;

  bool get _actionable =>
      (widget.state == DpNextActionState.ready ||
          widget.state == DpNextActionState.retry) &&
      widget.onPressed != null;

  bool get _keepsFocus => widget.state == DpNextActionState.pending;

  void _activate() {
    if (_actionable) widget.onPressed!(widget.actionId);
  }

  @override
  Widget build(BuildContext context) {
    final band = DecoratedBox(
      decoration: BoxDecoration(
        color: context.dpColors.surface,
        border: Border.all(color: context.dpColors.border),
        borderRadius: BorderRadius.circular(context.appTokens.panelRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DpSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PrimaryAction(
              widget: widget,
              focused: _focused,
              hovered: _hovered,
              actionable: _actionable,
              keepsFocus: _keepsFocus,
              onActivate: _activate,
              onFocusChanged: (value) {
                if (mounted) setState(() => _focused = value);
              },
              onHoverChanged: (value) {
                if (mounted) setState(() => _hovered = value);
              },
            ),
            if (widget.state == DpNextActionState.disabled &&
                widget.disabledReason != null) ...[
              const SizedBox(height: DpSpacing.sm),
              Text(
                widget.disabledReason!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.dpColors.textSecondary,
                ),
              ),
            ],
            if (widget.subordinateActionId != null &&
                widget.subordinateLabel != null) ...[
              const SizedBox(height: DpSpacing.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: widget.onSubordinatePressed == null
                      ? null
                      : () => widget.onSubordinatePressed!(
                          widget.subordinateActionId!,
                        ),
                  child: Text(widget.subordinateLabel!),
                ),
              ),
            ],
          ],
        ),
      ),
    );

    if (widget.variant == DpNextActionBandVariant.stickySafe) {
      return SafeArea(
        top: false,
        minimum: const EdgeInsets.all(1),
        child: band,
      );
    }
    return band;
  }
}

class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({
    required this.widget,
    required this.focused,
    required this.hovered,
    required this.actionable,
    required this.keepsFocus,
    required this.onActivate,
    required this.onFocusChanged,
    required this.onHoverChanged,
  });

  final DpNextActionBand widget;
  final bool focused;
  final bool hovered;
  final bool actionable;
  final bool keepsFocus;
  final VoidCallback onActivate;
  final ValueChanged<bool> onFocusChanged;
  final ValueChanged<bool> onHoverChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.dpColors;
    final displayedLabel = switch (widget.state) {
      DpNextActionState.ready || DpNextActionState.disabled => widget.label,
      DpNextActionState.pending => widget.pendingLabel ?? '처리 중',
      DpNextActionState.retry => widget.retryLabel,
      DpNextActionState.completed => '완료됨',
    };
    final fill = switch (widget.state) {
      DpNextActionState.ready || DpNextActionState.retry =>
        hovered
            // 같은 primary-action pair의 파생 overlay다. primaryText는 면에
            // 사용하지 않고 focus/text 역할로만 유지한다.
            ? Color.alphaBlend(
                colors.onPrimary.withValues(alpha: 0.08),
                colors.primary,
              )
            : colors.primary,
      DpNextActionState.pending ||
      DpNextActionState.completed => colors.accentSoft,
      DpNextActionState.disabled => colors.surfaceMuted,
    };
    final foreground = switch (widget.state) {
      DpNextActionState.ready || DpNextActionState.retry => colors.onPrimary,
      DpNextActionState.pending ||
      DpNextActionState.completed => colors.primaryTextStrong,
      DpNextActionState.disabled => colors.textSecondary,
    };
    final semanticLabel = '$displayedLabel, 예상 결과: ${widget.expectedOutcome}';
    final enabled = actionable;

    return Semantics(
      label: semanticLabel,
      hint: widget.state == DpNextActionState.disabled
          ? widget.disabledReason
          : null,
      button: true,
      enabled: enabled,
      liveRegion:
          widget.state == DpNextActionState.pending ||
          widget.state == DpNextActionState.completed,
      onTap: actionable ? onActivate : null,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: actionable ? SystemMouseCursors.click : MouseCursor.defer,
        onEnter: (_) => onHoverChanged(true),
        onExit: (_) => onHoverChanged(false),
        child: FocusableActionDetector(
          focusNode: widget.focusNode,
          enabled:
              widget.state != DpNextActionState.disabled &&
              widget.state != DpNextActionState.completed,
          onFocusChange: onFocusChanged,
          onShowFocusHighlight: onFocusChanged,
          shortcuts: const {
            SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
            SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
          },
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                onActivate();
                return null;
              },
            ),
          },
          child: ExcludeSemantics(
            child: InkWell(
              key: const ValueKey('dp-next-action-primary'),
              onTap: actionable || keepsFocus ? onActivate : null,
              canRequestFocus: false,
              borderRadius: BorderRadius.circular(DpRadius.button),
              child: AnimatedContainer(
                key: const ValueKey('dp-next-action-primary-surface'),
                duration: DpMotion.resolve(context, DpDurations.select),
                constraints: const BoxConstraints(minHeight: 44),
                padding: const EdgeInsets.symmetric(
                  horizontal: DpSpacing.lg,
                  vertical: DpSpacing.md,
                ),
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: BorderRadius.circular(DpRadius.button),
                  border: Border.all(
                    color: focused ? colors.primaryText : colors.accentLine,
                    width: focused ? 2 : 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      displayedLabel,
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.labelLarge?.copyWith(color: foreground),
                    ),
                    const SizedBox(height: DpSpacing.xs),
                    Text(
                      widget.expectedOutcome,
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: foreground),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
