// QuillClipboardConfig.enableExternalRichPaste 는 flutter_quill 11.5.1에서
// @experimental 로 표시돼 있지만, 웹 리치 붙여넣기 크래시(I-2)를 막는 유일한
// 공개 API다. 라이브러리가 stable API로 승격하면 이 ignore 는 제거한다.
// ignore_for_file: experimental_member_use
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/community_source.dart';
import 'widgets/quill_markdown.dart';
import 'widgets/rich_editor.dart';

/// 일반 게시글(FREE/FEEDBACK) 작성. `POST /community/posts {boardType,title,bodyMd,tags[]}`
/// → 상세로 이동. 본문은 WYSIWYG 에디터로 입력하고 게시 시 마크다운으로 변환한다.
class PostCreatePage extends ConsumerStatefulWidget {
  const PostCreatePage({
    super.key,
    required this.board,
    @visibleForTesting this.bodyController,
  });

  /// 보드 프리셋 — 'FREE'(자유) | 'FEEDBACK'(피드백 요청).
  final String board;

  /// 테스트에서 본문 문서를 결정적으로 주입하기 위한 선택 파라미터.
  /// null 이면 페이지가 직접 생성·해제한다.
  @visibleForTesting
  final QuillController? bodyController;

  @override
  ConsumerState<PostCreatePage> createState() => _PostCreatePageState();
}

class _PostCreatePageState extends ConsumerState<PostCreatePage> {
  final _titleCtrl = TextEditingController();
  final _tagsCtrl = TextEditingController();
  late final QuillController _bodyController;
  late final bool _ownsBodyController;
  bool _submitting = false;

  bool get _isFeedback => widget.board == 'FEEDBACK';
  String get _pageTitle => _isFeedback ? '피드백 요청' : '자유글 작성';

  @override
  void initState() {
    super.initState();
    final injected = widget.bodyController;
    _ownsBodyController = injected == null;
    // 웹은 clipboard 의 HTML 을 읽어 <img> 를 image 임베드로 변환하는데(플랫폼
    // 기본값 enableExternalRichPaste=true), QuillEditor.basic 에 embedBuilders 가
    // 없어 렌더 시 UnimplementedError 로 크래시한다. 저장 계약이 마크다운
    // 전용이라 서식 붙여넣기 자체가 무손실 표현 대상이 아니므로, 외부 리치
    // 붙여넣기를 꺼서 평문으로 강등시킨다.
    _bodyController =
        injected ??
        QuillController.basic(
          config: const QuillControllerConfig(
            clipboardConfig: QuillClipboardConfig(
              enableExternalRichPaste: false,
            ),
          ),
        );
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _tagsCtrl.dispose();
    if (_ownsBodyController) _bodyController.dispose();
    super.dispose();
  }

  List<String> _parseTags() => _tagsCtrl.text
      .split(RegExp(r'[,\s]+'))
      .map((t) => t.trim())
      .where((t) => t.isNotEmpty)
      .toList();

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    final isBodyEmpty = _bodyController.document.toPlainText().trim().isEmpty;
    if (title.isEmpty || isBodyEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('제목과 본문을 입력해 주세요.')));
      return;
    }
    setState(() => _submitting = true);
    try {
      final body = quillToMarkdown(_bodyController).trim();
      final created = await ref.read(postCreateProvider)(
        boardType: widget.board,
        title: title,
        bodyMd: body,
        tags: _parseTags(),
      );
      if (mounted) context.go('/community/post/${created.id}');
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('본문을 변환하지 못했어요. 서식을 단순화한 뒤 다시 시도해 주세요.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 문서형 화면 — 헤더를 첫 sliver로 실어 폼과 함께 스크롤시킨다(DESIGN.md §9).
    // 본문 에디터(DpRichEditor)는 고정 높이(260px)의 자체 스크롤 영역이라
    // sliver 안에서도 높이가 유한하고, 페이지 스크롤과 경쟁하지 않는다.
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: DpPageHeader(
              title: _pageTitle,
              description: '자유롭게 쓰거나 코드 피드백을 요청하세요',
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(DpSpacing.lg),
            sliver: SliverList.list(
              children: [
                TextField(
                  controller: _titleCtrl,
                  enabled: !_submitting,
                  decoration: const InputDecoration(
                    labelText: '제목',
                    hintText: '제목을 입력하세요',
                    border: OutlineInputBorder(),
                  ),
                ),
                // 본문 안내 문구는 헤더 설명과 같은 말이라 제거했다(3-A Task 14-3).
                // 헤더가 더 눈에 띄는 자리이고, 2단계 스펙 §5가 그 문구를 지정했다.
                const SizedBox(height: DpSpacing.md),
                DpRichEditor(
                  key: const ValueKey('post-body-editor'),
                  controller: _bodyController,
                  enabled: !_submitting,
                ),
                const SizedBox(height: DpSpacing.md),
                TextField(
                  controller: _tagsCtrl,
                  enabled: !_submitting,
                  decoration: const InputDecoration(
                    labelText: '태그',
                    hintText: '쉼표 또는 공백으로 구분 (예: dart, flutter)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: DpSpacing.lg),
                // SliverList.list의 직접 자식은 가로로 늘어난다 — 감싸지 않으면
                // 넓은 화면에서 버튼 하나가 콘텐츠 폭 전체를 차지한다(실측 1368px).
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: _submitting ? null : _submit,
                    icon: const Icon(DpIcons.send, size: 18),
                    label: Text(_submitting ? '게시 중…' : '게시'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
