import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

/// 커뮤니티 작성 본문용 WYSIWYG 에디터(웹 전용).
///
/// 저장 계약은 마크다운(`bodyMd`)이므로 툴바는 **마크다운으로 무손실 표현
/// 가능한 서식만** 노출한다(색·폰트·밑줄·정렬 등은 비활성). 변환은
/// `quillToMarkdown` 이 담당한다.
class DpRichEditor extends StatelessWidget {
  const DpRichEditor({
    super.key,
    required this.controller,
    this.enabled = true,
    this.height = 260,
  });

  final QuillController controller;

  /// 제출 중 입력 잠금.
  final bool enabled;

  /// 에디터 영역 고정 높이(내부 스크롤).
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.dpColors;
    return AbsorbPointer(
      absorbing: !enabled,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: c.border),
          borderRadius: BorderRadius.circular(DpRadius.input),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            QuillSimpleToolbar(
              controller: controller,
              config: const QuillSimpleToolbarConfig(
                // ON — 마크다운 무손실
                showBoldButton: true,
                showItalicButton: true,
                showStrikeThrough: true,
                showHeaderStyle: true,
                showListBullets: true,
                showListNumbers: true,
                showQuote: true,
                showCodeBlock: true,
                showInlineCode: true,
                showLink: true,
                showUndo: true,
                showRedo: true,
                // OFF — 마크다운 비표현 또는 범위 외
                showFontFamily: false,
                showFontSize: false,
                showColorButton: false,
                showBackgroundColorButton: false,
                showUnderLineButton: false,
                showListCheck: false,
                showSubscript: false,
                showSuperscript: false,
                showSmallButton: false,
                showLineHeightButton: false,
                showAlignmentButtons: false,
                showDirection: false,
                showIndent: false,
                showClearFormat: false,
                showSearchButton: false,
                multiRowsDisplay: false,
              ),
            ),
            const Divider(height: 1),
            SizedBox(
              height: height,
              child: Padding(
                padding: const EdgeInsets.all(DpSpacing.sm),
                child: QuillEditor.basic(controller: controller),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
