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
    _bodyController = injected ?? QuillController.basic();
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
    final body = quillToMarkdown(_bodyController).trim();
    setState(() => _submitting = true);
    try {
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_pageTitle)),
      body: ListView(
        padding: const EdgeInsets.all(DpSpacing.lg),
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
          const SizedBox(height: DpSpacing.md),
          Text(
            _isFeedback ? '리뷰받고 싶은 코드/프로젝트와 궁금한 점을 적어주세요' : '나누고 싶은 이야기를 적어주세요',
            style: TextStyle(color: context.dpColors.textSecondary),
          ),
          const SizedBox(height: DpSpacing.xs),
          DpRichEditor(controller: _bodyController, enabled: !_submitting),
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
          FilledButton.icon(
            onPressed: _submitting ? null : _submit,
            icon: const Icon(DpIcons.send, size: 18),
            label: Text(_submitting ? '게시 중…' : '게시'),
          ),
        ],
      ),
    );
  }
}
