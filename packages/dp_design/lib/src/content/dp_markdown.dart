import 'package:flutter/material.dart';
import 'package:markdown_widget/markdown_widget.dart';

/// 마크다운 + 코드 하이라이트 공용 렌더러. 스크롤은 부모가 담당(MarkdownBlock).
class DpMarkdown extends StatelessWidget {
  const DpMarkdown({super.key, required this.data});
  final String data;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final config = isDark
        ? MarkdownConfig.darkConfig
        : MarkdownConfig.defaultConfig;
    return MarkdownBlock(
      data: data,
      config: config.copy(
        configs: [isDark ? PreConfig.darkConfig : const PreConfig()],
      ),
    );
  }
}
