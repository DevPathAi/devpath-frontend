import 'dart:convert';

import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../dashboard/application/current_mission_controller.dart';
import '../application/mentor_controller.dart';
import '../application/mentor_workspace_retention.dart';
import '../state/mentor_scope_key.dart';
import '../state/mentor_state.dart';
import 'web_mentor_context_projection.dart';

const _kExamples = ['비동기란?', '테스트는 어떻게 작성하나요?', 'Riverpod이 뭔가요?'];

/// 하단에서 이 픽셀 이내면 새 메시지·토큰을 자동 추종(더 멀면 사용자가 읽는 중으로 보고 억제).
const double _kFollowThreshold = 120;

class MentorPage extends ConsumerStatefulWidget {
  const MentorPage({super.key})
    : scopeKey = null,
      includeCurrentCode = false,
      includeReviewSummary = false;

  const MentorPage.contextual({
    super.key,
    required this.scopeKey,
    this.includeCurrentCode = false,
    this.includeReviewSummary = false,
  });

  final MentorScopeKey? scopeKey;
  final bool includeCurrentCode;
  final bool includeReviewSummary;

  @override
  ConsumerState<MentorPage> createState() => _MentorPageState();
}

class _MentorPageState extends ConsumerState<MentorPage> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _capsuleDisclosureFocus = FocusNode();
  bool? _capsuleExpandedOverride;
  MentorWorkspaceRetentionController? _retention;

  bool get _isContextual => widget.scopeKey != null;

  @override
  void initState() {
    super.initState();
    _input.addListener(_onInputChanged);
    _scheduleContextInitialization();
  }

  @override
  void didUpdateWidget(covariant MentorPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scopeKey != widget.scopeKey ||
        oldWidget.includeCurrentCode != widget.includeCurrentCode ||
        oldWidget.includeReviewSummary != widget.includeReviewSummary) {
      final oldScope = oldWidget.scopeKey;
      if (oldScope != null) _retention?.deactivate(oldScope);
      _capsuleExpandedOverride = null;
      _scheduleContextInitialization();
    }
  }

  void _scheduleContextInitialization() {
    final scope = widget.scopeKey;
    if (scope == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.scopeKey != scope) return;
      _retention = ref.read(mentorWorkspaceRetentionProvider.notifier);
      _retention!.activate(scope);
      ref
          .read(contextualMentorControllerProvider(scope).notifier)
          .initializeContext(
            includeCurrentCode: widget.includeCurrentCode,
            includeReviewSummary: widget.includeReviewSummary,
          );
    });
  }

  void _onInputChanged() {
    if (mounted && _isContextual) setState(() {});
  }

  @override
  void dispose() {
    final scope = widget.scopeKey;
    if (scope != null) _retention?.deactivate(scope);
    _input.removeListener(_onInputChanged);
    _input.dispose();
    _scroll.dispose();
    _capsuleDisclosureFocus.dispose();
    super.dispose();
  }

  MentorController _controller() {
    final scope = widget.scopeKey;
    return scope == null
        ? ref.read(mentorControllerProvider.notifier)
        : ref.read(contextualMentorControllerProvider(scope).notifier);
  }

  MentorState _watchState() {
    final scope = widget.scopeKey;
    return scope == null
        ? ref.watch(mentorControllerProvider)
        : ref.watch(contextualMentorControllerProvider(scope));
  }

  /// 하단 근처일 때만 새 메시지·토큰을 하단으로 추종(위로 읽는 중이면 억제).
  void _autoFollow() {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    if (position.maxScrollExtent - position.pixels > _kFollowThreshold) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  void _listenForMessages() {
    void listener(MentorState? previous, MentorState next) {
      final grew = (previous?.messages.length ?? 0) != next.messages.length;
      final tailChanged =
          previous != null &&
          previous.messages.isNotEmpty &&
          next.messages.isNotEmpty &&
          previous.messages.last.text != next.messages.last.text;
      if (grew || tailChanged) _autoFollow();
    }

    final scope = widget.scopeKey;
    if (scope == null) {
      ref.listen(mentorControllerProvider, listener);
    } else {
      ref.listen(contextualMentorControllerProvider(scope), listener);
    }
  }

  void _listenForOwnerChanges() {
    if (_isContextual) return;
    ref.listen(currentMissionOwnerKeyProvider, (previous, owner) {
      if (previous == owner) return;
      _input.clear();
      _capsuleExpandedOverride = null;
    });
  }

  Future<void> _sendLegacy(String question) async {
    final normalized = question.trim();
    if (normalized.isEmpty) return;
    _input.clear();
    await _controller().send(normalized);
  }

  Future<void> _handleContextualPrimary(MentorState state) async {
    final question = _input.text.trim();
    if (question.isEmpty || _contextBusy(state)) return;
    final messageCountBefore = state.messages.length;
    final sameQuestion = state.previewQuestion == question;
    final hasPreview = sameQuestion && state.contextPreview != null;

    if (sameQuestion &&
        state.committedSnapshotId != null &&
        (state.status == MentorStatus.partial ||
            state.status == MentorStatus.busy ||
            state.status == MentorStatus.failed)) {
      await _controller().retry();
    } else if (hasPreview &&
        state.contextPhase == MentorContextPhase.previewReady) {
      await _controller().commitAndSend();
    } else {
      await _controller().preparePreview(question);
    }

    if (!mounted) return;
    final next = ref.read(contextualMentorControllerProvider(widget.scopeKey!));
    if (next.status == MentorStatus.idle &&
        next.messages.length > messageCountBefore &&
        _input.text.trim() == question) {
      _input.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    _listenForOwnerChanges();
    _listenForMessages();
    final state = _watchState();
    return _isContextual
        ? _buildContextual(context, state)
        : _buildLegacy(context, state);
  }

  Widget _buildLegacy(BuildContext context, MentorState state) {
    final colors = context.dpColors;
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const DpPageHeader(
            title: 'AI 멘토',
            description: '막히는 부분을 물어보면 학습 맥락을 반영해 답합니다',
          ),
          Expanded(
            child: Column(
              children: [
                if (state.status == MentorStatus.killSwitch)
                  const DpKillSwitch()
                else
                  Expanded(child: _conversation(state)),
                if (state.status == MentorStatus.partial)
                  _PartialNotice(
                    message: state.error,
                    onRetry: _controller().retry,
                  ),
                if (state.status == MentorStatus.busy)
                  _PartialNotice(
                    message: state.error,
                    onRetry: _controller().retry,
                  ),
                if (state.status == MentorStatus.failed && state.error != null)
                  _InlineError(message: state.error!, color: colors.danger),
                if (state.references.isNotEmpty)
                  _ReferencePanel(references: state.references),
                if (state.status != MentorStatus.killSwitch)
                  _LegacyComposer(controller: _input, onSend: _sendLegacy),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContextual(BuildContext context, MentorState state) {
    final scope = widget.scopeKey!;
    final mission = ref.watch(currentMissionControllerProvider).mission;
    final matches = mission?.tasks
        .where(
          (task) =>
              task.taskId == scope.workspaceKey.taskId &&
              task.contentId == scope.workspaceKey.contentId,
        )
        .toList(growable: false);
    final task = matches?.length == 1 ? matches!.single : null;
    final compactOrMedium = MediaQuery.sizeOf(context).width < 840;
    final capsuleExpanded = _capsuleExpandedOverride ?? !compactOrMedium;
    final previewMatches =
        state.contextPreview != null &&
        state.previewQuestion == _input.text.trim();
    final capsuleMode = previewMatches && capsuleExpanded
        ? DpContextCapsuleMode.payloadPreview
        : capsuleExpanded
        ? DpContextCapsuleMode.expanded
        : DpContextCapsuleMode.collapsed;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            WebMentorContextProjection(
              mission: mission,
              task: task,
              fields: _contextFields(state, previewMatches),
              capsuleMode: capsuleMode,
              capsuleStatus: _capsuleStatus(state),
              statusMessage: state.contextError,
              disclosureFocusNode: _capsuleDisclosureFocus,
              onDisclosurePressed: () =>
                  setState(() => _capsuleExpandedOverride = !capsuleExpanded),
              onFieldEditRequested: (_) => _showContextEditor(),
              onRetry: () => _controller().preparePreview(_input.text.trim()),
            ),
            Expanded(
              child: state.status == MentorStatus.killSwitch
                  ? const DpKillSwitch()
                  : _conversation(state),
            ),
            if (state.status == MentorStatus.partial)
              _PartialText(message: state.error),
            if (state.status == MentorStatus.busy)
              _PartialText(message: state.error),
            if (state.status == MentorStatus.failed && state.error != null)
              _InlineError(
                message: state.error!,
                color: context.dpColors.danger,
              ),
            if (state.references.isNotEmpty)
              _ReferencePanel(references: state.references),
            if (state.status != MentorStatus.killSwitch)
              _ContextualComposer(
                controller: _input,
                enabled: !_contextBusy(state),
                pending: _contextBusy(state),
                actionLabel: _contextualActionLabel(state),
                onPressed: () => _handleContextualPrimary(state),
              ),
          ],
        ),
      ),
    );
  }

  Widget _conversation(MentorState state) => state.messages.isEmpty
      ? _Empty(
          onPick: _isContextual
              ? (value) {
                  _input.text = value;
                  _input.selection = TextSelection.collapsed(
                    offset: value.length,
                  );
                }
              : _sendLegacy,
        )
      : ListView.builder(
          controller: _scroll,
          padding: const EdgeInsets.all(DpSpacing.lg),
          itemCount: state.messages.length,
          itemBuilder: (_, index) {
            final isStreamingTail =
                index == state.messages.length - 1 &&
                state.status == MentorStatus.streaming;
            return _Bubble(
              key: ValueKey('msg-$index-${state.messages[index].fromUser}'),
              message: state.messages[index],
              isStreamingTail: isStreamingTail,
            );
          },
        );

  bool _contextBusy(MentorState state) =>
      state.contextPhase == MentorContextPhase.loadingPreview ||
      state.contextPhase == MentorContextPhase.committing ||
      state.status == MentorStatus.streaming;

  String _contextualActionLabel(MentorState state) {
    if (state.contextPhase == MentorContextPhase.loadingPreview) {
      return '미리보는 중…';
    }
    if (state.contextPhase == MentorContextPhase.committing ||
        state.status == MentorStatus.streaming) {
      return '질문 보내는 중…';
    }
    final question = _input.text.trim();
    final sameQuestion = state.previewQuestion == question;
    if (sameQuestion &&
        state.committedSnapshotId != null &&
        (state.status == MentorStatus.partial ||
            state.status == MentorStatus.busy ||
            state.status == MentorStatus.failed)) {
      return '같은 질문 다시 보내기';
    }
    if (state.contextPhase == MentorContextPhase.failed) {
      return '맥락 미리보기 다시 만들기';
    }
    if (sameQuestion &&
        state.contextPreview != null &&
        state.contextPhase == MentorContextPhase.previewReady) {
      return '비공개로 질문 보내기';
    }
    return '맥락 미리보기';
  }

  DpContextCapsuleStatus _capsuleStatus(MentorState state) =>
      switch (state.contextPhase) {
        MentorContextPhase.loadingPreview ||
        MentorContextPhase.committing => DpContextCapsuleStatus.loading,
        MentorContextPhase.failed => DpContextCapsuleStatus.error,
        MentorContextPhase.selecting ||
        MentorContextPhase.previewReady => DpContextCapsuleStatus.ready,
      };

  List<DpContextFieldViewModel> _contextFields(
    MentorState state,
    bool previewMatches,
  ) {
    final preview = previewMatches ? state.contextPreview : null;
    final optionById = {
      for (final option in state.contextOptions) option.id: option,
    };
    final ids = <String>[
      ...state.contextOptions.map((option) => option.id),
      if (preview != null) ...preview.fieldsAvailable,
      if (preview != null)
        ...preview.fieldsUnavailable.map((field) => field.field),
      if (preview != null) ...preview.content.keys,
    ];
    final seen = <String>{};
    return [
      for (final id in ids)
        if (seen.add(id)) _contextField(id, optionById[id], preview: preview),
    ];
  }

  DpContextFieldViewModel _contextField(
    String id,
    MentorContextOption? option, {
    required LcsDraft? preview,
  }) {
    LcsFieldUnavailable? unavailable;
    if (preview != null) {
      for (final field in preview.fieldsUnavailable) {
        if (field.field == id) {
          unavailable = field;
          break;
        }
      }
    }
    final included = preview == null
        ? option?.selected == true && option?.available == true
        : preview.fieldsAvailable.contains(id);
    final rejected = unavailable != null || option?.available == false;
    final value = preview?.content[id];
    final summary = preview == null
        ? _selectionSummary(id, option)
        : included
        ? _previewSummary(value)
        : _unavailableSummary(unavailable?.reason, option?.unavailableReason);
    return DpContextFieldViewModel(
      id: id,
      label: _fieldLabel(id),
      valueSummary: summary,
      source: _fieldSource(id),
      sensitivity: switch (id) {
        'current_content' => DpContextSensitivity.low,
        'review_summary' => DpContextSensitivity.medium,
        'current_code' => DpContextSensitivity.potentiallySensitive,
        _ => DpContextSensitivity.potentiallySensitive,
      },
      inclusion: included
          ? DpContextInclusion.included
          : rejected
          ? DpContextInclusion.rejected
          : DpContextInclusion.excluded,
      editable: option?.available == true,
    );
  }

  String _selectionSummary(String id, MentorContextOption? option) {
    if (option?.available == false) {
      return option?.unavailableReason ?? '이 출처는 지금 사용할 수 없어요.';
    }
    if (option?.selected != true) return '이 질문에서는 보내지 않아요.';
    return switch (id) {
      'current_content' => '현재 미션의 콘텐츠 정보',
      'current_code' => '현재 편집기에 보이는 코드',
      'recent_errors' => '저장된 최근 실행의 오류 출력',
      'recent_output' => '저장된 최근 실행의 표준 출력과 오류 출력',
      'review_summary' => '현재 실행과 연결된 코드 리뷰 요약',
      _ => '선택한 학습 맥락',
    };
  }

  String _previewSummary(Object? value) {
    if (value == null) return '서버 미리보기에 값이 없어요.';
    String text;
    if (value is Map) {
      final map = value.cast<Object?, Object?>();
      final preferred =
          [
                map['title'],
                map['track'],
                map['confidence'] == null ? null : '신뢰도 ${map['confidence']}%',
                if (map['strengths'] is List)
                  (map['strengths'] as List).join(', '),
                map['stdout'],
                map['stderr'],
                map['truncated'] == true ? '일부 출력 생략됨' : null,
              ]
              .whereType<Object>()
              .map((part) => part.toString())
              .where((part) => part.trim().isNotEmpty);
      text = preferred.join(' · ');
      if (text.isEmpty) text = jsonEncode(value);
    } else if (value is List) {
      text = value.join('\n');
    } else {
      text = value.toString();
    }
    final normalized = text.trim();
    if (normalized.length <= 360) return normalized;
    return '${normalized.substring(0, 360)}…';
  }

  String _unavailableSummary(String? reason, String? localReason) {
    if (localReason != null) return localReason;
    return switch (reason) {
      'request_context_missing' => '선택한 출처의 값을 준비하지 못했어요.',
      'source_unavailable' => '해당 출처를 지금 불러오지 못했어요.',
      'not_requested' => '이 질문에서는 보내지 않아요.',
      null => '이 질문에서는 보내지 않아요.',
      _ => '서버 미리보기에서 사용할 수 없는 항목이에요.',
    };
  }

  String _fieldLabel(String id) => switch (id) {
    'current_content' => '현재 콘텐츠',
    'current_code' => '현재 편집기 코드',
    'recent_errors' => '최근 오류',
    'recent_output' => '최근 실행 결과',
    'review_summary' => '기존 코드 리뷰',
    _ => '추가 학습 맥락',
  };

  String _fieldSource(String id) => switch (id) {
    'current_content' => '현재 미션 콘텐츠',
    'current_code' => '실습 편집기',
    'recent_errors' || 'recent_output' => '저장된 실행 결과',
    'review_summary' => '현재 실행의 코드 리뷰',
    _ => '학습 맥락 서비스',
  };

  Future<void> _showContextEditor() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final current = ref.read(
            contextualMentorControllerProvider(widget.scopeKey!),
          );
          return AlertDialog(
            title: const Text('질문에 보낼 맥락 선택'),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final option in current.contextOptions)
                      CheckboxListTile(
                        value: option.selected,
                        onChanged: option.available
                            ? (_) {
                                _controller().toggleContextField(option.id);
                                setDialogState(() {});
                              }
                            : null,
                        title: Text(_fieldLabel(option.id)),
                        subtitle: option.available
                            ? null
                            : Text(
                                option.unavailableReason ??
                                    '이 출처는 지금 사용할 수 없어요.',
                              ),
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('완료'),
              ),
            ],
          );
        },
      ),
    );
    if (mounted) _capsuleDisclosureFocus.requestFocus();
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onPick});
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(DpSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const DpEmpty(
            icon: DpIcons.mentor,
            title: '첫 질문을 해보세요',
            message: '학습 중 막힌 부분을 물어보세요.',
          ),
          Wrap(
            spacing: DpSpacing.sm,
            runSpacing: DpSpacing.sm,
            alignment: WrapAlignment.center,
            children: [
              for (final example in _kExamples)
                ActionChip(
                  label: Text(example),
                  onPressed: () => onPick(example),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    super.key,
    required this.message,
    this.isStreamingTail = false,
  });
  final ChatMessage message;

  /// 스트리밍 중인 마지막 멘토 버블 여부(자주 갱신되는 유일한 버블).
  final bool isStreamingTail;

  @override
  Widget build(BuildContext context) {
    final colors = context.dpColors;
    final alignment = message.fromUser
        ? Alignment.centerRight
        : Alignment.centerLeft;
    final background = message.fromUser ? colors.primary : colors.surface;
    final foreground = message.fromUser ? colors.onPrimary : colors.textPrimary;
    final showTyping = !message.fromUser && message.text.isEmpty;
    final usedContext = message.contextFields.map(_contextLabel).join(' · ');

    return Align(
      alignment: alignment,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.86,
        ),
        margin: const EdgeInsets.symmetric(vertical: DpSpacing.xs),
        padding: const EdgeInsets.all(DpSpacing.md),
        decoration: BoxDecoration(
          color: background,
          border: Border.all(color: colors.border),
          borderRadius: BorderRadius.circular(DpRadius.card),
        ),
        child: showTyping
            ? const SizedBox(
                width: 24,
                height: 12,
                child: LinearProgressIndicator(),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message.text,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: foreground),
                  ),
                  if (!message.fromUser &&
                      message.contextFields.isNotEmpty) ...[
                    const SizedBox(height: DpSpacing.sm),
                    Text(
                      '답변에 사용된 맥락 · $usedContext',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  static String _contextLabel(String id) => switch (id) {
    'current_content' => '현재 콘텐츠',
    'current_code' => '현재 편집기 코드',
    'recent_errors' => '최근 오류',
    'recent_output' => '최근 실행 결과',
    'review_summary' => '기존 코드 리뷰',
    _ => '추가 학습 맥락',
  };
}

class _PartialNotice extends StatelessWidget {
  const _PartialNotice({required this.message, required this.onRetry});
  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: DpSpacing.lg,
      vertical: DpSpacing.sm,
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            message ?? '연결이 끊겼어요. 부분답변을 받았어요.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.dpColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: DpSpacing.sm),
        TextButton(onPressed: onRetry, child: const Text('다시 시도')),
      ],
    ),
  );
}

class _PartialText extends StatelessWidget {
  const _PartialText({required this.message});
  final String? message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: DpSpacing.lg),
    child: Text(
      message ?? '연결이 끊겼어요. 받은 답변은 그대로 두었어요.',
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(color: context.dpColors.textSecondary),
    ),
  );
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, required this.color});
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: DpSpacing.lg),
    child: Semantics(
      liveRegion: true,
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
      ),
    ),
  );
}

/// `event:references`로 받은 콘텐츠 링크를 표시한다.
class _ReferencePanel extends StatelessWidget {
  const _ReferencePanel({required this.references});
  final List<MentorReference> references;

  @override
  Widget build(BuildContext context) {
    final colors = context.dpColors;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DpSpacing.lg,
        vertical: DpSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '참고자료',
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: DpSpacing.xs),
          Wrap(
            spacing: DpSpacing.sm,
            runSpacing: DpSpacing.xs,
            children: [
              for (final reference in references)
                ActionChip(
                  key: ValueKey('ref-${reference.contentId}'),
                  avatar: const Icon(DpIcons.content, size: 16),
                  label: Text(reference.title),
                  onPressed: () =>
                      context.go('/content/${reference.contentId}'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegacyComposer extends StatelessWidget {
  const _LegacyComposer({required this.controller, required this.onSend});
  final TextEditingController controller;
  final ValueChanged<String> onSend;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(DpSpacing.md),
    child: Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            onSubmitted: onSend,
            decoration: const InputDecoration(
              hintText: '질문을 입력하세요',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: DpSpacing.sm),
        IconButton.filled(
          tooltip: '전송',
          onPressed: () => onSend(controller.text),
          icon: const Icon(DpIcons.send),
        ),
      ],
    ),
  );
}

class _ContextualComposer extends StatelessWidget {
  const _ContextualComposer({
    required this.controller,
    required this.enabled,
    required this.pending,
    required this.actionLabel,
    required this.onPressed,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool pending;
  final String actionLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final field = TextField(
      controller: controller,
      minLines: 1,
      maxLines: 3,
      textInputAction: TextInputAction.send,
      onSubmitted: enabled ? (_) => onPressed() : null,
      decoration: const InputDecoration(
        hintText: '현재 미션에서 막힌 점을 질문하세요',
        border: OutlineInputBorder(),
      ),
    );
    final action = FilledButton(
      key: const ValueKey('mentor-primary-action'),
      onPressed: enabled ? onPressed : null,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Center(
          child: pending
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(actionLabel, textAlign: TextAlign.center),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.all(DpSpacing.md),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 520) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                field,
                const SizedBox(height: DpSpacing.sm),
                action,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: field),
              const SizedBox(width: DpSpacing.sm),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 180),
                child: action,
              ),
            ],
          );
        },
      ),
    );
  }
}
