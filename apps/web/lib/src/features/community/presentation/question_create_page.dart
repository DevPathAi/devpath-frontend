import 'dart:async';

import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/community_source.dart';

/// 질문 작성(FAB). `POST /community/questions {title, bodyMd, tags[]}` → 즉시 게시(AI 시드는 비동기).
/// 제목 입력 중 유사질문(`GET /community/questions/similar?q=`)을 디바운스로 안내해 중복을 줄인다.
class QuestionCreatePage extends ConsumerStatefulWidget {
  const QuestionCreatePage({super.key});

  @override
  ConsumerState<QuestionCreatePage> createState() => _QuestionCreatePageState();
}

class _QuestionCreatePageState extends ConsumerState<QuestionCreatePage> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _tagsCtrl = TextEditingController();

  Timer? _debounce;
  List<SimilarQuestion> _similar = const [];
  bool _submitting = false;

  static const _debounceDelay = Duration(milliseconds: 400);

  @override
  void dispose() {
    _debounce?.cancel();
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _tagsCtrl.dispose();
    super.dispose();
  }

  void _onTitleChanged(String q) {
    _debounce?.cancel();
    final text = q.trim();
    if (text.length < 2) {
      setState(() => _similar = const []);
      return;
    }
    _debounce = Timer(_debounceDelay, () => _fetchSimilar(text));
  }

  Future<void> _fetchSimilar(String q) async {
    try {
      final results = await ref.read(similarQuestionsProvider)(q);
      if (mounted) setState(() => _similar = results);
    } on ApiException {
      // 유사질문은 비블로킹 — 실패 시 조용히 빈 목록(설계서 D-5).
      if (mounted) setState(() => _similar = const []);
    }
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
      final created = await ref.read(questionCreateProvider)(
        title: title,
        bodyMd: body,
        tags: _parseTags(),
      );
      if (mounted) context.go('/community/${created.id}');
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
    final c = context.dpColors;
    return Scaffold(
      appBar: AppBar(title: const Text('질문하기')),
      body: ListView(
        padding: const EdgeInsets.all(DpSpacing.lg),
        children: [
          TextField(
            controller: _titleCtrl,
            enabled: !_submitting,
            onChanged: _onTitleChanged,
            decoration: const InputDecoration(
              labelText: '제목',
              hintText: '무엇이 궁금한가요?',
              border: OutlineInputBorder(),
            ),
          ),
          if (_similar.isNotEmpty) ...[
            const SizedBox(height: DpSpacing.sm),
            Card(
              color: c.surface,
              child: Padding(
                padding: const EdgeInsets.all(DpSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '💡 비슷한 질문',
                      style: TextStyle(
                        color: c.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: DpSpacing.xs),
                    for (final s in _similar)
                      InkWell(
                        onTap: () => context.go('/community/${s.questionId}'),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: DpSpacing.xs,
                          ),
                          child: Text(
                            s.title,
                            style: TextStyle(color: c.primaryText),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: DpSpacing.md),
          TextField(
            controller: _bodyCtrl,
            enabled: !_submitting,
            minLines: 5,
            maxLines: 12,
            decoration: const InputDecoration(
              labelText: '본문 (Markdown)',
              hintText: '상황과 시도한 내용을 적어주세요',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: DpSpacing.md),
          TextField(
            controller: _tagsCtrl,
            enabled: !_submitting,
            decoration: const InputDecoration(
              labelText: '태그',
              hintText: '쉼표 또는 공백으로 구분 (예: dart, async)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: DpSpacing.lg),
          FilledButton.icon(
            onPressed: _submitting ? null : _submit,
            icon: const Icon(DpIcons.send, size: 18),
            label: Text(_submitting ? '게시 중…' : '질문 게시'),
          ),
        ],
      ),
    );
  }
}
