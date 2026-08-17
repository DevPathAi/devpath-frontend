import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:markdown_widget/markdown_widget.dart';

import '../theme/dp_colors.dart';
import '../theme/dp_spacing.dart';
import '../theme/dp_typography.dart';

@visibleForTesting
({bool? pending, bool shouldSchedule}) resolveDpMarkdownOverflowTransition({
  required bool committed,
  required bool? pending,
  required bool next,
}) {
  if (next == committed) {
    return (pending: null, shouldSchedule: false);
  }
  if (next == pending) {
    return (pending: pending, shouldSchedule: false);
  }
  return (pending: next, shouldSchedule: true);
}

/// 마크다운 + 코드 하이라이트 공용 렌더러. 스크롤은 부모가 담당(MarkdownBlock).
class DpMarkdown extends StatelessWidget {
  const DpMarkdown({super.key, required this.data});

  /// 16px 본문에서 영문 약 70–75자가 한 줄에 머무는 읽기 폭.
  static const double readingMaxWidth = 720;

  final String data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.dpColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final preBase = isDark ? PreConfig.darkConfig : const PreConfig();
    final bodyStyle = theme.textTheme.bodyLarge!.copyWith(
      fontFamily: DpTypography.family,
      fontSize: 16,
      height: 1.6,
      color: colors.textPrimary,
    );
    final codeStyle = DpTypography.code.copyWith(color: colors.codeText);
    const prePadding = EdgeInsets.all(DpSpacing.lg);
    const preMargin = EdgeInsets.symmetric(vertical: DpSpacing.sm);
    final preDecoration = BoxDecoration(
      color: colors.codeEditorBg,
      border: Border.all(color: colors.border),
      borderRadius: const BorderRadius.all(Radius.circular(DpRadius.input)),
    );
    final config = MarkdownConfig(
      configs: [
        PConfig(textStyle: bodyStyle),
        H1Config(
          style: theme.textTheme.headlineSmall!.copyWith(
            fontFamily: DpTypography.family,
            color: colors.textPrimary,
          ),
        ),
        H2Config(
          style: theme.textTheme.titleLarge!.copyWith(
            fontFamily: DpTypography.family,
            color: colors.textPrimary,
          ),
        ),
        H3Config(
          style: theme.textTheme.titleMedium!.copyWith(
            fontFamily: DpTypography.family,
            color: colors.textPrimary,
          ),
        ),
        H4Config(
          style: theme.textTheme.titleSmall!.copyWith(
            fontFamily: DpTypography.family,
            color: colors.textPrimary,
          ),
        ),
        H5Config(
          style: theme.textTheme.titleSmall!.copyWith(
            fontFamily: DpTypography.family,
            color: colors.textPrimary,
          ),
        ),
        H6Config(
          style: theme.textTheme.titleSmall!.copyWith(
            fontFamily: DpTypography.family,
            color: colors.textPrimary,
          ),
        ),
        CodeConfig(
          style: DpTypography.code.copyWith(
            color: colors.primaryTextStrong,
            backgroundColor: colors.surfaceMuted,
          ),
        ),
        PreConfig(
          padding: prePadding,
          margin: preMargin,
          textStyle: codeStyle,
          styleNotMatched: codeStyle,
          decoration: preDecoration,
          theme: preBase.theme,
          language: preBase.language,
          builder: (code, language) => _DpCodeBlock(
            code: code,
            language: language,
            fallbackLanguage: preBase.language,
            highlightTheme: preBase.theme,
            padding: prePadding,
            margin: preMargin,
            decoration: preDecoration,
            textStyle: codeStyle,
            focusColor: colors.primaryText,
          ),
        ),
        LinkConfig(
          style: TextStyle(
            fontFamily: DpTypography.family,
            color: colors.primaryText,
            decoration: TextDecoration.underline,
            decorationColor: colors.primaryText,
          ),
        ),
        HrConfig(height: 1, color: colors.border),
        BlockquoteConfig(
          sideColor: colors.accentLine,
          textColor: colors.textSecondary,
          padding: const EdgeInsets.fromLTRB(DpSpacing.lg, 2, 0, 2),
          margin: const EdgeInsets.symmetric(vertical: DpSpacing.sm),
        ),
      ],
    );

    return Align(
      alignment: AlignmentDirectional.topStart,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: readingMaxWidth),
        child: SizedBox(
          width: double.infinity,
          child: _DpSelectableMarkdown(data: data, config: config),
        ),
      ),
    );
  }
}

/// Keeps whole-document selection without putting its manager ahead of the
/// interactive code regions in keyboard traversal.
class _DpSelectableMarkdown extends StatefulWidget {
  const _DpSelectableMarkdown({required this.data, required this.config});

  final String data;
  final MarkdownConfig config;

  @override
  State<_DpSelectableMarkdown> createState() => _DpSelectableMarkdownState();
}

class _DpSelectableMarkdownState extends State<_DpSelectableMarkdown> {
  late final FocusNode _selectionFocusNode = FocusNode(
    debugLabel: 'DpMarkdown selection',
    skipTraversal: true,
  );

  @override
  void dispose() {
    _selectionFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      focusNode: _selectionFocusNode,
      child: MarkdownBlock(
        data: widget.data,
        config: widget.config,
        selectable: false,
      ),
    );
  }
}

/// Keeps the upstream code-block layout while making horizontal overflow a
/// keyboard-reachable region. The surrounding [SelectionArea] still owns text
/// selection.
class _DpCodeBlock extends StatefulWidget {
  const _DpCodeBlock({
    required this.code,
    required this.language,
    required this.fallbackLanguage,
    required this.highlightTheme,
    required this.padding,
    required this.margin,
    required this.decoration,
    required this.textStyle,
    required this.focusColor,
  });

  final String code;
  final String language;
  final String fallbackLanguage;
  final Map<String, TextStyle> highlightTheme;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Decoration decoration;
  final TextStyle textStyle;
  final Color focusColor;

  @override
  State<_DpCodeBlock> createState() => _DpCodeBlockState();
}

class _DpCodeBlockState extends State<_DpCodeBlock> {
  static const double _keyboardScrollStep = 48;

  late final FocusNode _focusNode = FocusNode(
    debugLabel: 'DpMarkdown code block',
  );
  final ScrollController _scrollController = ScrollController();
  bool _focused = false;
  bool _hasHorizontalOverflow = false;
  bool? _pendingHorizontalOverflow;

  @override
  void dispose() {
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final direction = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowLeft => -1,
      LogicalKeyboardKey.arrowRight => 1,
      _ => 0,
    };
    if (direction == 0 || !_scrollController.hasClients) {
      return KeyEventResult.ignored;
    }
    final position = _scrollController.position;
    final next = (position.pixels + direction * _keyboardScrollStep)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    _scrollController.jumpTo(next);
    return KeyEventResult.handled;
  }

  bool _handleScrollMetrics(ScrollMetricsNotification notification) {
    final hasOverflow =
        notification.metrics.maxScrollExtent >
        notification.metrics.minScrollExtent;
    final transition = resolveDpMarkdownOverflowTransition(
      committed: _hasHorizontalOverflow,
      pending: _pendingHorizontalOverflow,
      next: hasOverflow,
    );
    _pendingHorizontalOverflow = transition.pending;
    if (!transition.shouldSchedule) return false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _pendingHorizontalOverflow != hasOverflow) return;
      _pendingHorizontalOverflow = null;
      if (!hasOverflow) _focusNode.unfocus();
      setState(() {
        _hasHorizontalOverflow = hasOverflow;
        if (!hasOverflow) _focused = false;
      });
    });
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final lines = widget.code.trim().split(WidgetVisitor.defaultSplitRegExp);
    if (lines.last.isEmpty) lines.removeLast();

    return Container(
      decoration: widget.decoration,
      margin: widget.margin,
      padding: widget.padding,
      width: double.infinity,
      child: NotificationListener<ScrollMetricsNotification>(
        key: const ValueKey('dp-markdown-code-scroll-metrics'),
        onNotification: _handleScrollMetrics,
        child: SingleChildScrollView(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          child: DecoratedBox(
            key: const ValueKey('dp-markdown-code-focus-content'),
            position: DecorationPosition.foreground,
            decoration: _focused
                ? BoxDecoration(
                    border: Border.all(color: widget.focusColor, width: 2),
                    borderRadius: const BorderRadius.all(
                      Radius.circular(DpRadius.input),
                    ),
                  )
                : const BoxDecoration(),
            child: Stack(
              alignment: AlignmentDirectional.topStart,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final line in lines)
                      Text.rich(
                        TextSpan(
                          children: highLightSpans(
                            line,
                            language: widget.language.isEmpty
                                ? widget.fallbackLanguage
                                : widget.language,
                            theme: widget.highlightTheme,
                            textStyle: widget.textStyle,
                            styleNotMatched: widget.textStyle,
                          ),
                        ),
                      ),
                  ],
                ),
                if (_hasHorizontalOverflow)
                  Focus(
                    key: const ValueKey('dp-markdown-code-focus'),
                    focusNode: _focusNode,
                    onFocusChange: (focused) {
                      if (mounted) setState(() => _focused = focused);
                    },
                    onKeyEvent: _handleKeyEvent,
                    child: Semantics(
                      key: const ValueKey('dp-markdown-code-focus-target'),
                      label: '코드 블록. 좌우 화살표로 가로 스크롤',
                      child: const SizedBox(width: 1, height: 1),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
