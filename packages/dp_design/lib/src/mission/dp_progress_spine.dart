import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../icons/dp_icons.dart';
import '../theme/dp_colors.dart';
import '../theme/dp_spacing.dart';

enum DpProgressSpineLayout { vertical, horizontal, text }

enum DpProgressStepState { upcoming, current, completed, unavailable }

@immutable
class DpProgressStep {
  const DpProgressStep({
    required this.id,
    required this.label,
    required this.state,
  });

  final String id;
  final String label;
  final DpProgressStepState state;
}

/// 순서와 상태가 이미 결정된 step을 표시한다. route나 완료 상태를 계산하지 않는다.
class DpProgressSpine extends StatelessWidget {
  const DpProgressSpine({
    super.key,
    required this.steps,
    required this.currentStepId,
    this.layout = DpProgressSpineLayout.vertical,
    this.onStepPressed,
    this.label = '학습 진행 단계',
  });

  final List<DpProgressStep> steps;
  final String currentStepId;
  final DpProgressSpineLayout layout;
  final ValueChanged<String>? onStepPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    assert(steps.isNotEmpty, 'DpProgressSpine requires at least one step.');
    assert(
      steps.map((step) => step.id).toSet().length == steps.length,
      'DpProgressStep.id must be stable and unique.',
    );
    assert(
      steps.isEmpty || steps.any((step) => step.id == currentStepId),
      'currentStepId must identify a supplied step.',
    );
    assert(
      steps.isEmpty ||
          (steps
                      .where(
                        (step) => step.state == DpProgressStepState.current,
                      )
                      .length ==
                  1 &&
              steps
                      .singleWhere(
                        (step) => step.state == DpProgressStepState.current,
                      )
                      .id ==
                  currentStepId),
      'currentStepId and the single current step state must agree.',
    );

    List<Widget> buildChildren(double? horizontalItemWidth) => [
      for (var index = 0; index < steps.length; index++)
        _ProgressStepView(
          step: steps[index],
          index: index,
          count: steps.length,
          textOnly: layout == DpProgressSpineLayout.text,
          horizontalItemWidth: horizontalItemWidth,
          onPressed:
              onStepPressed != null &&
                  steps[index].state != DpProgressStepState.unavailable
              ? () => onStepPressed!(steps[index].id)
              : null,
        ),
    ];

    final Widget content = switch (layout) {
      DpProgressSpineLayout.vertical || DpProgressSpineLayout.text => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: buildChildren(null),
      ),
      DpProgressSpineLayout.horizontal => LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = constraints.hasBoundedWidth
              ? constraints.maxWidth
              : MediaQuery.sizeOf(context).width;
          final itemWidth = math.min(280.0, availableWidth);
          return Wrap(
            spacing: DpSpacing.md,
            runSpacing: DpSpacing.sm,
            children: buildChildren(itemWidth),
          );
        },
      ),
    };

    final currentIndex = steps.indexWhere((step) => step.id == currentStepId);
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: '$label, ${steps.length}개, 현재 ${currentIndex + 1}단계',
      child: content,
    );
  }
}

class _ProgressStepView extends StatelessWidget {
  const _ProgressStepView({
    required this.step,
    required this.index,
    required this.count,
    required this.textOnly,
    required this.horizontalItemWidth,
    required this.onPressed,
  });

  final DpProgressStep step;
  final int index;
  final int count;
  final bool textOnly;
  final double? horizontalItemWidth;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final stateLabel = switch (step.state) {
      DpProgressStepState.upcoming => '예정',
      DpProgressStepState.current => '현재 단계',
      DpProgressStepState.completed => '완료',
      DpProgressStepState.unavailable => '사용 불가',
    };
    final semanticLabel = '${index + 1}/$count ${step.label}, $stateLabel';
    Widget body(bool focused) => Semantics(
      label: semanticLabel,
      button: onPressed != null,
      enabled: step.state != DpProgressStepState.unavailable,
      selected: step.state == DpProgressStepState.current,
      excludeSemantics: true,
      child: _ProgressStepContent(
        step: step,
        ordinal: index + 1,
        textOnly: textOnly,
        horizontalItemWidth: horizontalItemWidth,
        focused: focused,
      ),
    );

    if (onPressed == null) return body(false);
    return _InteractiveProgressStep(
      stepId: step.id,
      onPressed: onPressed!,
      builder: body,
    );
  }
}

class _InteractiveProgressStep extends StatefulWidget {
  const _InteractiveProgressStep({
    required this.stepId,
    required this.onPressed,
    required this.builder,
  });

  final String stepId;
  final VoidCallback onPressed;
  final Widget Function(bool focused) builder;

  @override
  State<_InteractiveProgressStep> createState() =>
      _InteractiveProgressStepState();
}

class _InteractiveProgressStepState extends State<_InteractiveProgressStep> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      mouseCursor: SystemMouseCursors.click,
      onFocusChange: (value) => setState(() => _focused = value),
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onPressed();
            return null;
          },
        ),
      },
      child: InkWell(
        onTap: widget.onPressed,
        canRequestFocus: false,
        borderRadius: BorderRadius.circular(DpRadius.button),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          child: widget.builder(_focused),
        ),
      ),
    );
  }
}

class _ProgressStepContent extends StatelessWidget {
  const _ProgressStepContent({
    required this.step,
    required this.ordinal,
    required this.textOnly,
    required this.horizontalItemWidth,
    required this.focused,
  });

  final DpProgressStep step;
  final int ordinal;
  final bool textOnly;
  final double? horizontalItemWidth;
  final bool focused;

  @override
  Widget build(BuildContext context) {
    final colors = context.dpColors;
    final isCurrent = step.state == DpProgressStepState.current;
    final isCompleted = step.state == DpProgressStepState.completed;
    final isUnavailable = step.state == DpProgressStepState.unavailable;
    final foreground = isUnavailable
        ? colors.textSecondary
        : isCurrent
        ? colors.primaryTextStrong
        : colors.textPrimary;
    final indicatorColor = isCompleted
        ? colors.success
        : isCurrent
        ? colors.primary
        : colors.border;

    final content = Row(
      children: [
        if (textOnly)
          Text(
            '$ordinal.',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: foreground),
          )
        else
          AnimatedContainer(
            key: const ValueKey('dp-progress-step-indicator'),
            duration: DpMotion.resolve(context, DpDurations.select),
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: isCurrent ? indicatorColor : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(color: indicatorColor, width: 2),
            ),
            child: isCompleted
                ? Icon(DpIcons.stepDone, size: 18, color: colors.success)
                : null,
          ),
        const SizedBox(width: DpSpacing.sm),
        Expanded(
          child: Text(
            step.label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: foreground,
              fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ],
    );

    return AnimatedContainer(
      key: ValueKey('dp-progress-step-surface-${step.id}'),
      duration: DpMotion.resolve(context, DpDurations.select),
      width: horizontalItemWidth,
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.symmetric(
        horizontal: DpSpacing.sm,
        vertical: DpSpacing.xs,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(DpRadius.button),
        border: Border.all(
          color: focused ? colors.primaryText : Colors.transparent,
          width: 2,
        ),
      ),
      child: content,
    );
  }
}
