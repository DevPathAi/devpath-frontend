import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/community_source.dart';

/// 일반 게시글(FREE/FEEDBACK) 작성. `POST /community/posts {boardType,title,bodyMd,tags[]}`
/// → 상세로 이동. Q&A 작성(question_create_page)과 달리 유사질문·학습맥락 첨부는 없다.
class PostCreatePage extends ConsumerStatefulWidget {
  const PostCreatePage({super.key, required this.board});

  /// 보드 프리셋 — 'FREE'(자유) | 'FEEDBACK'(피드백 요청).
  final String board;

  @override
  ConsumerState<PostCreatePage> createState() => _PostCreatePageState();
}

class _PostCreatePageState extends ConsumerState<PostCreatePage> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _tagsCtrl = TextEditingController();
  bool _submitting = false;

  bool get _isFeedback => widget.board == 'FEEDBACK';
  String get _pageTitle => _isFeedback ? '피드백 요청' : '자유글 작성';

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _tagsCtrl.dispose();
    super.dispose();
  }

  List<String> _parseTags() => _tagsCtrl.text
      .split(RegExp(r'[,\s]+'))
      .map((t) => t.trim())
      .where((t) => t.isNotEmpty)
      .toList();

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    final body = _bodyCtrl.text.trim();
    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('제목과 본문을 입력해 주세요.')));
      return;
    }
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
          TextField(
            controller: _bodyCtrl,
            enabled: !_submitting,
            minLines: 5,
            maxLines: 12,
            decoration: InputDecoration(
              labelText: '본문 (Markdown)',
              hintText: _isFeedback
                  ? '리뷰받고 싶은 코드/프로젝트와 궁금한 점을 적어주세요'
                  : '나누고 싶은 이야기를 적어주세요',
              border: const OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
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
