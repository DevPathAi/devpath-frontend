import 'dart:async';

import 'package:dp_core/dp_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dp_design/dp_design.dart';

import '../application/community_controller.dart';
import '../data/community_source.dart';
import '../data/quick_capture_store.dart';
import '../../auth/application/auth_controller.dart';

/// 퀵 캡처 — 제목·본문·태그로 질문을 빠르게 게시(`POST /community/questions`).
class QuickCapturePage extends ConsumerStatefulWidget {
  const QuickCapturePage({super.key});

  @override
  ConsumerState<QuickCapturePage> createState() => _QuickCapturePageState();
}

class _QuickCapturePageState extends ConsumerState<QuickCapturePage> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _tagsCtrl = TextEditingController();
  bool _submitting = false;
  bool _restoring = true;
  String? _ownerKey;
  var _ownerGeneration = 0;

  @override
  void initState() {
    super.initState();
    for (final controller in [_titleCtrl, _bodyCtrl, _tagsCtrl]) {
      controller.addListener(_saveDraft);
    }
    ref.listenManual(
      currentOwnerKeyProvider,
      (_, owner) => _bindOwner(owner),
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    for (final controller in [_titleCtrl, _bodyCtrl, _tagsCtrl]) {
      controller.removeListener(_saveDraft);
    }
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _tagsCtrl.dispose();
    super.dispose();
  }

  void _bindOwner(String? owner) {
    if (owner == _ownerKey && _ownerGeneration != 0) return;
    _ownerKey = owner;
    final generation = ++_ownerGeneration;
    _restoring = true;
    _submitting = false;
    for (final controller in [_titleCtrl, _bodyCtrl, _tagsCtrl]) {
      controller.clear();
    }
    if (mounted) setState(() {});
    unawaited(_restoreDraft(owner, generation));
  }

  Future<void> _restoreDraft(String? owner, int generation) async {
    final draft = owner == null
        ? null
        : await ref.read(quickCaptureStoreProvider).read(owner);
    if (!_isCurrent(owner, generation)) return;
    if (draft != null) {
      _titleCtrl.text = draft.title;
      _bodyCtrl.text = draft.body;
      _tagsCtrl.text = draft.tags.join(', ');
    }
    _restoring = false;
    if (mounted) setState(() {});
  }

  void _saveDraft() {
    final owner = _ownerKey;
    if (_restoring || owner == null) return;
    final generation = _ownerGeneration;
    unawaited(
      ref
          .read(quickCaptureStoreProvider)
          .write(
            owner,
            QuickCaptureDraft(
              title: _titleCtrl.text,
              body: _bodyCtrl.text,
              tags: _parseTags(),
            ),
            isCurrent: () => _isCurrent(owner, generation),
          ),
    );
  }

  List<String> _parseTags() => _tagsCtrl.text
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  Future<void> _submit() async {
    final owner = _ownerKey;
    final generation = _ownerGeneration;
    if (owner == null || !_isCurrent(owner, generation)) return;
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
      await ref.read(questionCreateProvider)(
        title: title,
        bodyMd: body,
        tags: _parseTags(),
      );
      if (!_isCurrent(owner, generation)) return;
      await ref
          .read(quickCaptureStoreProvider)
          .clear(owner, isCurrent: () => _isCurrent(owner, generation));
      if (!_isCurrent(owner, generation)) return;
      // 목록 갱신 후 닫기.
      await ref.read(communityControllerProvider.notifier).load();
      if (!_isCurrent(owner, generation)) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('질문을 게시했어요.')));
      context.pop();
    } on ApiException catch (e) {
      if (!_isCurrent(owner, generation)) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  bool _isCurrent(String? owner, int generation) =>
      mounted && owner == _ownerKey && generation == _ownerGeneration;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('퀵 캡처')),
      body: ListView(
        padding: const EdgeInsets.all(DpSpacing.lg),
        children: [
          TextField(
            controller: _titleCtrl,
            decoration: const InputDecoration(
              labelText: '제목',
              hintText: '무엇이 궁금한가요?',
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: DpSpacing.md),
          TextField(
            controller: _bodyCtrl,
            decoration: const InputDecoration(
              labelText: '본문',
              hintText: '자세한 내용을 적어 주세요',
              alignLabelWithHint: true,
            ),
            minLines: 4,
            maxLines: 10,
          ),
          const SizedBox(height: DpSpacing.md),
          TextField(
            controller: _tagsCtrl,
            decoration: const InputDecoration(
              labelText: '태그(쉼표로 구분)',
              hintText: 'dart, async',
            ),
          ),
          const SizedBox(height: DpSpacing.xl),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: Text(_submitting ? '게시 중…' : '게시'),
          ),
        ],
      ),
    );
  }
}
