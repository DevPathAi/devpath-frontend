import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

/// 커뮤니티 작성 본문용 WYSIWYG 에디터(웹 전용).
///
/// 저장 계약은 마크다운(`bodyMd`)이므로 툴바는 **마크다운으로 무손실 표현
/// 가능한 서식만** 노출한다(색·폰트·밑줄·정렬 등은 비활성). 변환은
/// `quillToMarkdown` 이 담당한다.
class DpRichEditor extends StatefulWidget {
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
  State<DpRichEditor> createState() => _DpRichEditorState();
}

class _DpRichEditorState extends State<DpRichEditor> {
  // QuillEditor.basic 은 focusNode/scrollController 를 넘기지 않으면 build 마다
  // 새 인스턴스를 만든다(pub cache flutter_quill-11.5.1 editor.dart:163-164).
  // DpRichEditor 가 StatelessWidget 이던 시절엔 상위에서 setState 가 발화할 때마다
  // 이 위젯이 통째로 교체돼 FocusNode 도 매번 새로 생성됐고, 아무도 dispose 하지
  // 않아 포커스·IME 연결이 끊겼다(질문 작성 화면의 유사질문 패널 삽입이 대표 사례).
  // State 가 두 컨트롤을 소유·해제해 인스턴스를 안정시킨다.
  late final FocusNode _focusNode;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final enabled = widget.enabled;
    final height = widget.height;
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
                child: QuillEditor.basic(
                  controller: controller,
                  focusNode: _focusNode,
                  scrollController: _scrollController,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
