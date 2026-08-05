// QuillClipboardConfig.enableExternalRichPaste 는 flutter_quill 11.5.1에서
// @experimental 로 표시돼 있지만, 웹 리치 붙여넣기 크래시(I-2)를 막는 유일한
// 공개 API다. 라이브러리가 stable API로 승격하면 이 ignore 는 제거한다.
// ignore_for_file: experimental_member_use
import 'dart:async';

import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/community_source.dart';
import '../data/lcs_source.dart';
import 'lcs_context.dart';
import 'widgets/quill_markdown.dart';
import 'widgets/rich_editor.dart';

/// 질문 작성(FAB). `POST /community/questions {title, bodyMd, tags[]}` → 즉시 게시(AI 시드는 비동기).
/// 제목 입력 중 유사질문(`GET /community/questions/similar?q=`)을 디바운스로 안내해 중복을 줄인다.
class QuestionCreatePage extends ConsumerStatefulWidget {
  const QuestionCreatePage({super.key, @visibleForTesting this.bodyController});

  /// 테스트에서 본문 문서를 결정적으로 주입하기 위한 선택 파라미터.
  /// null 이면 페이지가 직접 생성·해제한다.
  @visibleForTesting
  final QuillController? bodyController;

  @override
  ConsumerState<QuestionCreatePage> createState() => _QuestionCreatePageState();
}

class _QuestionCreatePageState extends ConsumerState<QuestionCreatePage> {
  final _titleCtrl = TextEditingController();
  final _tagsCtrl = TextEditingController();
  late final QuillController _bodyController;
  late final bool _ownsBodyController;

  Timer? _debounce;
  List<SimilarQuestion> _similar = const [];
  bool _submitting = false;

  /// 맥락 카드가 통지한 첨부 선택값(없으면 미첨부). 게시 후 commit 에 사용.
  LcsAttach? _attach;

  static const _debounceDelay = Duration(milliseconds: 400);

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
    _debounce?.cancel();
    _titleCtrl.dispose();
    _tagsCtrl.dispose();
    if (_ownsBodyController) _bodyController.dispose();
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
      final created = await ref.read(questionCreateProvider)(
        title: title,
        bodyMd: body,
        tags: _parseTags(),
      );
      // 맥락 첨부(opt-in): 게시 응답 questionId 로 draft 를 commit. best-effort —
      // 첨부 실패가 게시를 막지 않는다(질문은 이미 생성됨).
      final attach = _attach;
      if (attach != null) {
        try {
          await ref.read(lcsCommitProvider)(
            draftId: attach.draftId,
            attachedToId: created.id,
            visibility: attach.visibility,
          );
        } on ApiException {
          // 맥락 첨부 실패는 무시(게시는 성공).
        }
      }
      if (mounted) context.go('/community/${created.id}');
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
    final c = context.dpColors;
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const DpPageHeader(
            title: '질문하기',
            description: '무엇을 시도했고 어디서 막혔는지 함께 적어주세요',
          ),
          Expanded(
            child: ListView(
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
                              onTap: () =>
                                  context.go('/community/${s.questionId}'),
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
                Text(
                  '상황과 시도한 내용을 적어주세요',
                  style: TextStyle(color: c.textSecondary),
                ),
                const SizedBox(height: DpSpacing.xs),
                DpRichEditor(
                  key: const ValueKey('question-body-editor'),
                  controller: _bodyController,
                  enabled: !_submitting,
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
                const SizedBox(height: DpSpacing.md),
                LcsContextCard(
                  enabled: !_submitting,
                  onChanged: (a) => _attach = a,
                ),
                const SizedBox(height: DpSpacing.lg),
                FilledButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: const Icon(DpIcons.send, size: 18),
                  label: Text(_submitting ? '게시 중…' : '질문 게시'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
