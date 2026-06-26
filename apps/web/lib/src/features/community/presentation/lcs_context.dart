import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/lcs_source.dart';

/// LCS(학습 맥락 자동 첨부) 프론트 위젯 — 질문 작성 폼 맥락 카드 + 질문 상세 답변자 패널.

/// 필드 키 → 한글 라벨(키: lcs-svc `SnapshotAssembler` 필드명).
String lcsFieldLabel(String key) => switch (key) {
  'current_content' => '현재 콘텐츠',
  'recent_activity' => '최근 활동',
  'current_path' => '학습 경로',
  'active_tags' => '관심 태그',
  'tag_reputation' => '태그 평판',
  'recent_errors' => '최근 오류',
  _ => key,
};

/// 작성 폼이 게시 시 commit 에 쓰는 첨부 선택값.
typedef LcsAttach = ({String draftId, String visibility});

const _visibilityOptions = <String, String>{
  'answerers_only': '답변자에게만',
  'public': '전체 공개',
  'private': '비공개',
};

/// 질문 작성 폼의 **맥락 카드**: opt-in 토글 → `draft` 조립 미리보기(필드 칩) + 노출범위 선택.
/// 부모(작성 페이지)는 [onChanged]로 받은 [LcsAttach]를 게시 후 commit 에 사용한다.
/// 토글 off 또는 조립 실패 시 `null` 을 통지한다.
class LcsContextCard extends ConsumerStatefulWidget {
  const LcsContextCard({
    super.key,
    required this.enabled,
    required this.onChanged,
  });

  /// 게시 진행 중이면 비활성.
  final bool enabled;
  final ValueChanged<LcsAttach?> onChanged;

  @override
  ConsumerState<LcsContextCard> createState() => _LcsContextCardState();
}

class _LcsContextCardState extends ConsumerState<LcsContextCard> {
  bool _on = false;
  bool _loading = false;
  LcsDraft? _draft;
  String? _error;
  String _visibility = 'answerers_only';

  Future<void> _toggle(bool on) async {
    setState(() {
      _on = on;
      _error = null;
    });
    if (!on) {
      setState(() => _draft = null);
      widget.onChanged(null);
      return;
    }
    setState(() => _loading = true);
    try {
      final draft = await ref.read(lcsDraftProvider)(requestedFields: const []);
      if (!mounted) return;
      setState(() {
        _draft = draft;
        _loading = false;
      });
      widget.onChanged((draftId: draft.draftId, visibility: _visibility));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
        _on = false; // 실패 시 토글 원복(첨부 안 함)
      });
      widget.onChanged(null);
    }
  }

  void _setVisibility(String v) {
    setState(() => _visibility = v);
    final d = _draft;
    if (d != null) widget.onChanged((draftId: d.draftId, visibility: v));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dpColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('내 학습 맥락 첨부'),
          subtitle: Text(
            '현재 학습 상태를 답변자에게 보여줘 더 정확한 답을 받아요.',
            style: TextStyle(color: c.textSecondary, fontSize: 12),
          ),
          value: _on,
          onChanged: widget.enabled ? _toggle : null,
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: DpSpacing.xs),
            child: Text(
              '맥락을 불러오지 못했어요: $_error',
              style: TextStyle(color: c.textSecondary, fontSize: 12),
            ),
          ),
        if (_on && _loading)
          const Padding(
            padding: EdgeInsets.all(DpSpacing.md),
            child: Center(
              child: SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
        if (_on && !_loading && _draft != null) _preview(context, _draft!),
      ],
    );
  }

  Widget _preview(BuildContext context, LcsDraft d) {
    final c = context.dpColors;
    return Card(
      color: c.surface,
      child: Padding(
        padding: const EdgeInsets.all(DpSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '첨부할 맥락',
              style: TextStyle(
                color: c.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: DpSpacing.xs),
            if (d.fieldsAvailable.isEmpty)
              Text(
                '첨부할 학습 맥락이 아직 없어요.',
                style: TextStyle(color: c.textSecondary, fontSize: 12),
              )
            else
              Wrap(
                spacing: DpSpacing.xs,
                children: [
                  for (final f in d.fieldsAvailable)
                    Chip(label: Text(lcsFieldLabel(f))),
                ],
              ),
            const SizedBox(height: DpSpacing.sm),
            Text(
              '노출 범위',
              style: TextStyle(
                color: c.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: DpSpacing.xs),
            Wrap(
              spacing: DpSpacing.xs,
              children: [
                for (final e in _visibilityOptions.entries)
                  ChoiceChip(
                    label: Text(e.value),
                    selected: _visibility == e.key,
                    onSelected: (sel) {
                      if (sel) _setVisibility(e.key);
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 질문 상세의 **답변자 맥락 패널**: questionId 로 커밋 스냅샷을 역조회해 렌더.
/// 스냅샷이 없거나(404→null) 비면 아무것도 표시하지 않는다(비블로킹).
class LcsAnswererPanel extends ConsumerWidget {
  const LcsAnswererPanel({super.key, required this.questionId});

  final int questionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snap = switch (ref.watch(questionSnapshotProvider(questionId))) {
      AsyncData(:final value) => value,
      _ => null,
    };
    if (snap == null || snap.content.isEmpty) return const SizedBox.shrink();
    final c = context.dpColors;
    return Card(
      color: c.surface,
      child: Padding(
        padding: const EdgeInsets.all(DpSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '📚 작성자 학습 맥락',
              style: TextStyle(
                color: c.primaryText,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: DpSpacing.xs),
            Wrap(
              spacing: DpSpacing.xs,
              children: [
                for (final k in snap.content.keys)
                  Chip(label: Text(lcsFieldLabel(k))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
