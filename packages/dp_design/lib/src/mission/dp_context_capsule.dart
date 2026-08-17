import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../icons/dp_icons.dart';
import '../theme/dp_colors.dart';
import '../theme/dp_spacing.dart';
import '../theme/dp_tokens.dart';

enum DpContextCapsuleMode { collapsed, expanded, payloadPreview }

enum DpContextCapsuleStatus { ready, loading, partial, error }

enum DpContextSensitivity { low, medium, potentiallySensitive }

enum DpContextInclusion { included, excluded, rejected }

@immutable
class DpContextFieldViewModel {
  const DpContextFieldViewModel({
    required this.id,
    required this.label,
    required this.valueSummary,
    required this.source,
    required this.sensitivity,
    required this.inclusion,
    this.editable = false,
  });

  final String id;
  final String label;
  final String valueSummary;
  final String source;
  final DpContextSensitivity sensitivity;
  final DpContextInclusion inclusion;
  final bool editable;
}

/// 어떤 맥락이 표시/전송되는지 공개하는 controlled disclosure.
///
/// disclosure/edit/retry callback은 intent만 반환하며 원본 profile/payload를
/// 수정하거나 inclusion을 암묵적으로 바꾸지 않는다.
class DpContextCapsule extends StatelessWidget {
  const DpContextCapsule({
    super.key,
    required this.fields,
    required this.mode,
    this.name = '학습 맥락',
    this.status = DpContextCapsuleStatus.ready,
    this.statusMessage,
    this.disclosureFocusNode,
    this.onDisclosurePressed,
    this.onFieldEditRequested,
    this.onRetry,
  });

  final List<DpContextFieldViewModel> fields;
  final DpContextCapsuleMode mode;
  final String name;
  final DpContextCapsuleStatus status;
  final String? statusMessage;
  final FocusNode? disclosureFocusNode;
  final VoidCallback? onDisclosurePressed;
  final ValueChanged<String>? onFieldEditRequested;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.dpColors;
    final expanded = mode != DpContextCapsuleMode.collapsed;
    final approved = fields
        .where((field) => field.inclusion == DpContextInclusion.included)
        .length;

    return DecoratedBox(
      key: const ValueKey('dp-context-capsule-surface'),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(context.appTokens.panelRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ContextDisclosure(
            name: name,
            approvedCount: approved,
            totalCount: fields.length,
            expanded: expanded,
            focusNode: disclosureFocusNode,
            onPressed: onDisclosurePressed,
          ),
          AnimatedSize(
            key: const ValueKey('dp-context-capsule-content'),
            duration: DpMotion.resolve(context, DpDurations.panelExpand),
            alignment: Alignment.topCenter,
            child: expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(
                      DpSpacing.lg,
                      0,
                      DpSpacing.lg,
                      DpSpacing.lg,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Divider(color: colors.border),
                        if (mode == DpContextCapsuleMode.payloadPreview) ...[
                          Text(
                            '전송 범위 미리보기',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(color: colors.textPrimary),
                          ),
                          const SizedBox(height: DpSpacing.xs),
                          Text(
                            '포함 $approved개 · 제외 또는 거절 ${fields.length - approved}개',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: colors.textSecondary),
                          ),
                          const SizedBox(height: DpSpacing.md),
                        ],
                        if (status != DpContextCapsuleStatus.ready)
                          _CapsuleStatus(
                            status: status,
                            message: statusMessage,
                            onRetry: onRetry,
                          ),
                        if (status != DpContextCapsuleStatus.loading) ...[
                          if (status != DpContextCapsuleStatus.ready)
                            const SizedBox(height: DpSpacing.md),
                          for (
                            var index = 0;
                            index < fields.length;
                            index++
                          ) ...[
                            _ContextField(
                              field: fields[index],
                              onEditRequested:
                                  fields[index].editable &&
                                      onFieldEditRequested != null
                                  ? () =>
                                        onFieldEditRequested!(fields[index].id)
                                  : null,
                            ),
                            if (index != fields.length - 1)
                              const SizedBox(height: DpSpacing.sm),
                          ],
                        ],
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _ContextDisclosure extends StatefulWidget {
  const _ContextDisclosure({
    required this.name,
    required this.approvedCount,
    required this.totalCount,
    required this.expanded,
    required this.focusNode,
    required this.onPressed,
  });

  final String name;
  final int approvedCount;
  final int totalCount;
  final bool expanded;
  final FocusNode? focusNode;
  final VoidCallback? onPressed;

  @override
  State<_ContextDisclosure> createState() => _ContextDisclosureState();
}

class _ContextDisclosureState extends State<_ContextDisclosure> {
  bool _focused = false;

  void _activate() => widget.onPressed?.call();

  @override
  Widget build(BuildContext context) {
    final colors = context.dpColors;
    final radius = BorderRadius.circular(context.appTokens.panelRadius);

    return Semantics(
      label: '${widget.name}, ${widget.expanded ? '펼침' : '접힘'}',
      button: widget.onPressed != null,
      expanded: widget.expanded,
      onTap: widget.onPressed,
      excludeSemantics: true,
      child: FocusableActionDetector(
        focusNode: widget.focusNode,
        enabled: widget.onPressed != null,
        mouseCursor: widget.onPressed == null
            ? MouseCursor.defer
            : SystemMouseCursors.click,
        onFocusChange: (value) => setState(() => _focused = value),
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _activate();
              return null;
            },
          ),
        },
        child: InkWell(
          onTap: widget.onPressed,
          canRequestFocus: false,
          borderRadius: radius,
          child: AnimatedContainer(
            key: const ValueKey('dp-context-disclosure-focus-surface'),
            duration: DpMotion.resolve(context, DpDurations.select),
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: _focused ? colors.primaryText : Colors.transparent,
                width: 2,
              ),
            ),
            child: ConstrainedBox(
              key: const ValueKey('dp-context-disclosure'),
              constraints: const BoxConstraints(minHeight: 44),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: DpSpacing.lg,
                  vertical: DpSpacing.sm,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.name,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: colors.textPrimary),
                      ),
                    ),
                    Text(
                      '${widget.approvedCount}/${widget.totalCount} 포함',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: DpSpacing.sm),
                    Icon(
                      widget.expanded ? DpIcons.expandLess : DpIcons.expandMore,
                      color: colors.textSecondary,
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

class _CapsuleStatus extends StatelessWidget {
  const _CapsuleStatus({
    required this.status,
    required this.message,
    required this.onRetry,
  });

  final DpContextCapsuleStatus status;
  final String? message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.dpColors;
    final label =
        message ??
        switch (status) {
          DpContextCapsuleStatus.loading => '학습 맥락을 불러오는 중',
          DpContextCapsuleStatus.partial => '일부 학습 맥락을 불러오지 못했습니다.',
          DpContextCapsuleStatus.error => '학습 맥락을 새로 불러오지 못했습니다.',
          DpContextCapsuleStatus.ready => '',
        };
    final isError = status == DpContextCapsuleStatus.error;

    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceMuted,
          borderRadius: BorderRadius.circular(DpRadius.button),
          border: Border.all(color: isError ? colors.danger : colors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(DpSpacing.md),
          child: Wrap(
            spacing: DpSpacing.sm,
            runSpacing: DpSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isError ? colors.danger : colors.textSecondary,
                ),
              ),
              if (isError && onRetry != null)
                TextButton(onPressed: onRetry, child: const Text('다시 불러오기')),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContextField extends StatelessWidget {
  const _ContextField({required this.field, required this.onEditRequested});

  final DpContextFieldViewModel field;
  final VoidCallback? onEditRequested;

  @override
  Widget build(BuildContext context) {
    final colors = context.dpColors;
    final sensitivity = switch (field.sensitivity) {
      DpContextSensitivity.low => '낮은 민감도',
      DpContextSensitivity.medium => '중간 민감도',
      DpContextSensitivity.potentiallySensitive => '민감할 수 있음',
    };
    final inclusion = switch (field.inclusion) {
      DpContextInclusion.included => '포함됨',
      DpContextInclusion.excluded => '제외됨',
      DpContextInclusion.rejected => '거절됨',
    };
    final statusColor = switch (field.inclusion) {
      DpContextInclusion.included => colors.success,
      DpContextInclusion.excluded => colors.textSecondary,
      DpContextInclusion.rejected => colors.danger,
    };
    final editableLabel = field.editable ? '수정 가능' : '수정 불가';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(DpRadius.button),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DpSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              container: true,
              label:
                  '${field.label}, ${field.valueSummary}, 출처 ${field.source}, '
                  '$inclusion, $sensitivity, $editableLabel',
              excludeSemantics: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: DpSpacing.sm,
                    runSpacing: DpSpacing.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        field.label,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      Text(
                        inclusion,
                        style: Theme.of(
                          context,
                        ).textTheme.labelMedium?.copyWith(color: statusColor),
                      ),
                      Text(
                        sensitivity,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: colors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: DpSpacing.xs),
                  Text(
                    field.valueSummary,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: colors.textPrimary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: DpSpacing.xs),
            Wrap(
              spacing: DpSpacing.sm,
              runSpacing: DpSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ExcludeSemantics(
                  child: Text(
                    '출처 · ${field.source}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ),
                if (onEditRequested != null)
                  TextButton(
                    onPressed: onEditRequested,
                    child: const Text('전송 전에 수정'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
