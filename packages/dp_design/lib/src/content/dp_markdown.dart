import 'package:flutter/material.dart';
import 'package:markdown_widget/markdown_widget.dart';

import '../theme/dp_colors.dart';
import '../theme/dp_spacing.dart';
import '../theme/dp_typography.dart';

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
          padding: const EdgeInsets.all(DpSpacing.lg),
          margin: const EdgeInsets.symmetric(vertical: DpSpacing.sm),
          textStyle: codeStyle,
          styleNotMatched: codeStyle,
          decoration: BoxDecoration(
            color: colors.codeEditorBg,
            border: Border.all(color: colors.border),
            borderRadius: const BorderRadius.all(
              Radius.circular(DpRadius.input),
            ),
          ),
          theme: preBase.theme,
          language: preBase.language,
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
          child: MarkdownBlock(data: data, config: config),
        ),
      ),
    );
  }
}
