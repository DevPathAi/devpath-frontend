import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

/// 툴바 실제 높이(실측). `QuillSimpleToolbarConfig._toolbarSize` 가 private 이라
/// 외부에서 지정할 수 없어 측정값을 상수로 둔다. 작성 화면이 툴바를
/// `SliverPersistentHeader` 로 고정할 때 이 값을 쓴다.
/// `rich_editor_test.dart` 가 실제 높이와의 일치를 단언한다.
const double kDpRichEditorToolbarHeight = 42.0;

/// 툴바 아래 구분선 두께.
const double kDpRichEditorDividerHeight = 1.0;

/// 본문이 늘어날 수 있는 상한. 여기까지는 내용에 따라 커지고, 넘으면 에디터가
/// 자체 스크롤한다. 자체 스크롤을 아예 없애면 캐럿 추적이 깨지므로(문서 참조)
/// 없애는 대신 상한을 크게 둔다.
const double kDpRichEditorMaxHeight = 2000.0;

/// 커뮤니티 작성 본문용 WYSIWYG 에디터(웹 전용)의 툴바.
///
/// 저장 계약은 마크다운(`bodyMd`)이므로 **마크다운으로 무손실 표현 가능한
/// 서식만** 노출한다(색·폰트·밑줄·정렬 등은 비활성). 변환은
/// `quillToMarkdown` 이 담당한다.
class DpRichEditorToolbar extends StatelessWidget {
  const DpRichEditorToolbar({super.key, required this.controller});

  final QuillController controller;

  @override
  Widget build(BuildContext context) {
    final c = context.dpColors;
    // 고정됐을 때 본문이 뒤로 지나가므로 불투명해야 한다.
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(
          top: BorderSide(color: c.border),
          left: BorderSide(color: c.border),
          right: BorderSide(color: c.border),
        ),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(DpRadius.input),
        ),
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
          // Divider를 쓰면 안 된다. dp_design이 dividerColor를 정의하지 않아
          // Material 기본색이 적용되고, 좌우 테두리(c.border)와 색이 달라
          // 툴바-본문 이음매가 선으로 드러난다(사용자 실측).
          SizedBox(
            height: kDpRichEditorDividerHeight,
            child: ColoredBox(color: c.border),
          ),
        ],
      ),
    );
  }
}

/// 본문 입력 영역.
///
/// `minHeight`~`maxHeight` 사이에서 **내용에 따라 늘어난다.** 늘어나는 동안에는
/// 스크롤할 것이 없어 휠이 바깥 스크롤로 전달된다 — 고정 높이였을 때는 내부에
/// 스크롤할 내용이 없어도 에디터가 휠을 흡수해 페이지가 멈췄다.
///
/// ★자체 스크롤을 없애지(`scrollable: false`) 않는 이유★ — 그러면
/// `ScrollController` 에 클라이언트가 붙지 않아 flutter_quill 의 `bringIntoView`
/// 가 캐럿을 좇지 못한다. 타이핑 중 커서가 화면 밖으로 나가도 아무도 따라가지
/// 않았다(사용자 실측). 대신 `maxHeight` 를 크게 둬 같은 효과를 얻는다.
///
/// 스크롤 가능한 부모(작성 화면의 `CustomScrollView`) 안에 둔다.
class DpRichEditorBody extends StatefulWidget {
  const DpRichEditorBody({
    super.key,
    required this.controller,
    this.enabled = true,
    this.minHeight = 260,
    this.maxHeight = kDpRichEditorMaxHeight,
  });

  final QuillController controller;

  /// 제출 중 입력 잠금.
  final bool enabled;

  /// 빈 문서에서도 확보할 최소 높이.
  final double minHeight;

  /// 이 높이까지는 내용에 따라 늘어나고, 넘으면 에디터가 자체 스크롤한다.
  ///
  /// 자체 스크롤을 없애면(`scrollable: false`) 캐럿 추적이 깨지므로 유지하되,
  /// 값을 크게 둬 실질적으로 「내용만큼 늘어나는」 동작을 얻는다.
  final double maxHeight;

  @override
  State<DpRichEditorBody> createState() => _DpRichEditorBodyState();
}

class _DpRichEditorBodyState extends State<DpRichEditorBody> {
  // QuillEditor.basic 은 focusNode/scrollController 를 넘기지 않으면 build 마다
  // 새 인스턴스를 만든다(pub cache flutter_quill-11.5.1 editor.dart:163-164).
  // 이 위젯이 StatelessWidget 이던 시절엔 상위에서 setState 가 발화할 때마다
  // 통째로 교체돼 FocusNode 도 매번 새로 생성됐고, 아무도 dispose 하지 않아
  // 포커스·IME 연결이 끊겼다(질문 작성 화면의 유사질문 패널 삽입이 대표 사례).
  // State 가 두 컨트롤을 소유·해제해 인스턴스를 안정시킨다.
  //
  // scrollController 는 scrollable: false 여도 QuillEditor 생성자가 요구한다
  // (캐럿 추적에 쓴다).
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
    final c = context.dpColors;
    return AbsorbPointer(
      absorbing: !widget.enabled,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: c.border),
            right: BorderSide(color: c.border),
            bottom: BorderSide(color: c.border),
          ),
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(DpRadius.input),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(DpSpacing.sm),
          child: QuillEditor.basic(
            controller: widget.controller,
            focusNode: _focusNode,
            scrollController: _scrollController,
            config: QuillEditorConfig(
              minHeight: widget.minHeight,
              maxHeight: widget.maxHeight,
            ),
          ),
        ),
      ),
    );
  }
}

/// 툴바와 본문을 한 덩어리로 쓰는 형태.
///
/// 작성 화면은 툴바를 고정하기 위해 둘을 따로 배치하지만, 스크롤 부모가 없는
/// 곳에서는 이 위젯을 쓴다.
class DpRichEditor extends StatelessWidget {
  const DpRichEditor({
    super.key,
    required this.controller,
    this.enabled = true,
    this.minHeight = 260,
    this.maxHeight = kDpRichEditorMaxHeight,
  });

  final QuillController controller;
  final bool enabled;
  final double minHeight;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DpRichEditorToolbar(controller: controller),
        DpRichEditorBody(
          controller: controller,
          enabled: enabled,
          minHeight: minHeight,
          maxHeight: maxHeight,
        ),
      ],
    );
  }
}

/// 작성 화면에서 툴바를 상단에 고정하기 위한 sliver 델리게이트.
///
/// 높이는 실측 상수로 고정한다(`QuillSimpleToolbarConfig` 가 크기를 노출하지
/// 않는다). 툴바 자체가 배경색을 채우므로 본문이 뒤로 지나가도 겹쳐 보이지 않는다.
class DpRichEditorToolbarHeader extends SliverPersistentHeaderDelegate {
  const DpRichEditorToolbarHeader({required this.controller});

  final QuillController controller;

  static const double height =
      kDpRichEditorToolbarHeight + kDpRichEditorDividerHeight;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return DpRichEditorToolbar(controller: controller);
  }

  @override
  bool shouldRebuild(covariant DpRichEditorToolbarHeader oldDelegate) =>
      oldDelegate.controller != controller;
}
