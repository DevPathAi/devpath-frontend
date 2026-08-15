import 'dart:async';
import 'dart:convert';

import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../community/data/lcs_source.dart';
import '../../dashboard/application/current_mission_controller.dart';
import '../../review/application/review_controller.dart';
import '../../review/state/review_state.dart';
import '../../sandbox/application/run_controller.dart';
import '../../sandbox/application/sandbox_workspace_controller.dart';
import '../../sandbox/state/run_state.dart';
import '../data/mentor_sse_source.dart';
import '../state/mentor_scope_key.dart';
import '../state/mentor_state.dart';

typedef MentorClock = DateTime Function();
typedef MentorScopeValidator = bool Function();

final mentorClockProvider = Provider<MentorClock>((_) => DateTime.now);

/// Revalidates owner + exact Today task/content immediately before every
/// contextual draft, commit, and Mentor network side effect.
final mentorScopeValidatorProvider =
    Provider.family<MentorScopeValidator, MentorScopeKey>((ref, scope) {
      return () {
        if (ref.read(currentMissionOwnerKeyProvider) != scope.ownerId) {
          return false;
        }
        final mission = ref.read(currentMissionControllerProvider).mission;
        if (mission?.outcome != CurrentMissionOutcome.available) return false;
        final key = scope.workspaceKey;
        return mission!.tasks
                .where(
                  (task) =>
                      task.taskId == key.taskId &&
                      task.contentId == key.contentId,
                )
                .length ==
            1;
      };
    });

/// Exact local evidence available to the one-request Mentor preview.
/// Run output is exposed only from the owner GET payload retained on terminal
/// state. Combined rendered log lines never stand in for stdout/stderr.
final mentorContextEvidenceProvider =
    Provider.family<MentorContextEvidence, MentorScopeKey>((ref, scope) {
      final key = scope.workspaceKey;
      final draft = ref.watch(sandboxWorkspaceControllerProvider(key));
      final run = ref.watch(runControllerFamilyProvider(key));
      final review = ref.watch(reviewControllerFamilyProvider(key));
      final exactSession = run is RunTerminal && run.persisted
          ? run.session
          : null;
      final exactReview =
          run is RunTerminal &&
              review is ReviewLoaded &&
              review.sandboxSessionId == run.sandboxSessionId
          ? review.review
          : null;
      return MentorContextEvidence(
        currentCode: draft.context != null && draft.code.trim().isNotEmpty
            ? draft.code
            : null,
        session: exactSession,
        review: exactReview,
      );
    });

const _contextFieldOrder = <String>[
  'current_content',
  'current_code',
  'recent_errors',
  'recent_output',
  'review_summary',
];
const _oneRequestFields = <String>{
  'current_code',
  'recent_errors',
  'recent_output',
};

class MentorController extends Notifier<MentorState> {
  MentorController([this.scopeKey]);

  final MentorScopeKey? scopeKey;
  StreamSubscription<SseEvent>? _sub;
  Completer<void>? _inFlight;
  String? _lastQuestion;
  String? _lastLegacyContentId;
  int? _lastContextualContentId;
  int? _lastContextSnapshotId;
  List<String> _lastUsedContextFields = const [];
  ({bool includeCurrentCode, bool includeReviewSummary})?
  _pendingContextDefaults;
  var _generation = 0;
  var _disposed = false;
  var _contextInitialized = false;

  @override
  MentorState build() {
    _disposed = false;
    final scope = scopeKey;
    ref.listen(currentMissionOwnerKeyProvider, (previous, owner) {
      if (_disposed || previous == owner) return;
      if (scope == null || owner != scope.ownerId) {
        _resetForOwnershipChange();
      }
    });
    ref.onDispose(() {
      _disposed = true;
      _generation += 1;
      unawaited(_sub?.cancel());
      _completeInFlight();
    });
    return const MentorState();
  }

  void initializeContext({
    required bool includeCurrentCode,
    bool includeReviewSummary = false,
  }) {
    final scope = scopeKey;
    if (scope == null) return;
    if (_mustDeferContextDefaults) {
      _pendingContextDefaults = (
        includeCurrentCode: includeCurrentCode,
        includeReviewSummary: includeReviewSummary,
      );
      return;
    }
    _pendingContextDefaults = null;
    if (_contextInitialized) {
      _generation += 1;
      _clearRetryMetadata();
    }
    _contextInitialized = true;
    final evidence = ref.read(mentorContextEvidenceProvider(scope));
    state = state.copyWith(
      contextOptions: _contextOptions(
        evidence,
        includeCurrentCode: includeCurrentCode,
        includeReviewSummary: includeReviewSummary,
      ),
      contextPhase: MentorContextPhase.selecting,
      contextPreview: null,
      contextError: null,
      previewQuestion: null,
      committedSnapshotId: null,
    );
  }

  /// Refreshes availability without silently re-enabling a one-request field.
  void refreshContextSources() {
    final scope = scopeKey;
    if (scope == null) return;
    if (!_contextInitialized) {
      initializeContext(includeCurrentCode: false, includeReviewSummary: false);
      return;
    }
    final previous = {
      for (final option in state.contextOptions) option.id: option,
    };
    final refreshed =
        _contextOptions(
              ref.read(mentorContextEvidenceProvider(scope)),
              includeCurrentCode: false,
              includeReviewSummary: false,
            )
            .map((option) {
              final prior = previous[option.id];
              final selected = option.available && prior?.selected == true;
              return option.copyWith(selected: selected);
            })
            .toList(growable: false);
    state = state.copyWith(contextOptions: refreshed);
  }

  void toggleContextField(String field) {
    if (!_contextInitialized) return;
    final index = state.contextOptions.indexWhere(
      (option) => option.id == field,
    );
    if (index < 0 || !state.contextOptions[index].available) return;
    final options = [...state.contextOptions];
    final current = options[index];
    final nextSelected = !current.selected;
    if (!nextSelected &&
        options.where((option) => option.selected).length == 1) {
      return;
    }
    options[index] = current.copyWith(selected: nextSelected);
    _pendingContextDefaults = null;
    state = state.copyWith(
      contextOptions: List.unmodifiable(options),
      contextPhase: MentorContextPhase.selecting,
      contextPreview: null,
      contextError: null,
      previewQuestion: null,
      committedSnapshotId: null,
    );
  }

  Future<void> preparePreview(String question) async {
    final scope = scopeKey;
    final normalized = question.trim();
    if (scope == null || normalized.isEmpty) return;
    if (state.contextPhase == MentorContextPhase.loadingPreview ||
        state.contextPhase == MentorContextPhase.committing ||
        state.status == MentorStatus.streaming) {
      return;
    }
    if (_lastQuestion != null && normalized != _lastQuestion) {
      _clearRetryMetadata();
    }
    if (!_contextInitialized) {
      initializeContext(includeCurrentCode: false, includeReviewSummary: false);
    } else {
      _applyPendingContextDefaults();
      refreshContextSources();
    }
    if (!_scopeIsCurrent(scope)) {
      _contextFailure('현재 미션 소유권을 다시 확인해 주세요.');
      return;
    }
    final evidence = ref.read(mentorContextEvidenceProvider(scope));
    final selected = state.contextOptions
        .where((option) => option.selected && option.available)
        .map((option) => option.id)
        .toSet();
    final requestedFields = _contextFieldOrder
        .where(selected.contains)
        .toList(growable: false);
    if (requestedFields.isEmpty) {
      _contextFailure('질문에 사용할 맥락을 하나 이상 선택해 주세요.');
      return;
    }
    final requestContext = _requestContext(evidence, selected);
    final generation = ++_generation;
    state = state.copyWith(
      contextPhase: MentorContextPhase.loadingPreview,
      contextError: null,
      committedSnapshotId: normalized == state.previewQuestion
          ? state.committedSnapshotId
          : null,
    );
    try {
      final draft = await ref.read(mentorLcsDraftProvider)(
        contentId: scope.workspaceKey.contentId,
        requestedFields: requestedFields,
        requestContext: requestContext,
      );
      if (!_isCurrent(generation) || !_scopeIsCurrent(scope)) return;
      if (draft.draftId.trim().isEmpty ||
          !draft.expiresAt.isAfter(ref.read(mentorClockProvider)().toUtc())) {
        _contextFailure('맥락 미리보기가 만료됐어요. 새로 만들어 주세요.');
        return;
      }
      state = state.copyWith(
        contextPhase: MentorContextPhase.previewReady,
        contextPreview: draft,
        contextError: null,
        previewQuestion: normalized,
        committedSnapshotId: null,
      );
    } on Object catch (error) {
      if (!_isCurrent(generation)) return;
      _contextFailure(_contextErrorMessage(error));
    }
  }

  Future<void> commitAndSend() async {
    final scope = scopeKey;
    final draft = state.contextPreview;
    final question = state.previewQuestion;
    if (scope == null ||
        draft == null ||
        question == null ||
        state.contextPhase != MentorContextPhase.previewReady ||
        state.status == MentorStatus.streaming) {
      return;
    }
    if (!draft.expiresAt.isAfter(ref.read(mentorClockProvider)().toUtc())) {
      _contextFailure('맥락 미리보기가 만료됐어요. 새로 만들어 주세요.');
      return;
    }
    if (!_scopeIsCurrent(scope)) {
      _contextFailure('현재 미션 소유권을 다시 확인해 주세요.');
      return;
    }
    final generation = ++_generation;
    state = state.copyWith(
      contextPhase: MentorContextPhase.committing,
      contextError: null,
    );
    try {
      final snapshotId = await ref.read(mentorLcsCommitProvider)(
        draftId: draft.draftId,
      );
      if (!_isCurrent(generation) || !_scopeIsCurrent(scope)) return;
      state = state.copyWith(committedSnapshotId: snapshotId);
      _resetOneRequestSelections();
      await _sendStream(
        question,
        contextualContentId: scope.workspaceKey.contentId,
        contextSnapshotId: snapshotId,
        usedContextFields: List.unmodifiable(draft.fieldsAvailable),
      );
    } on Object catch (error) {
      if (!_isCurrent(generation)) return;
      _contextFailure(_contextErrorMessage(error));
    }
  }

  /// Contextless `/mentor` retains the existing request path and performs no
  /// LCS draft/commit calls.
  Future<void> send(String question, {String? contentId}) => _sendStream(
    question,
    legacyContentId: contentId,
    contextSnapshotId: null,
    usedContextFields: const [],
  );

  Future<void> _sendStream(
    String question, {
    String? legacyContentId,
    int? contextualContentId,
    required int? contextSnapshotId,
    required List<String> usedContextFields,
  }) {
    final normalized = question.trim();
    if (normalized.isEmpty) return Future.value();
    final scope = scopeKey;
    if (scope != null && !_scopeIsCurrent(scope)) {
      _contextFailure('현재 미션 소유권을 다시 확인해 주세요.');
      return Future.value();
    }
    unawaited(_sub?.cancel());
    _completeInFlight();
    final generation = ++_generation;
    _lastQuestion = normalized;
    _lastLegacyContentId = legacyContentId;
    _lastContextualContentId = contextualContentId;
    _lastContextSnapshotId = contextSnapshotId;
    _lastUsedContextFields = List.unmodifiable(usedContextFields);
    final done = Completer<void>();
    _inFlight = done;

    final messages = [
      ...state.messages,
      ChatMessage(fromUser: true, text: normalized),
      ChatMessage(fromUser: false, text: '', contextFields: usedContextFields),
    ];
    state = state.copyWith(
      messages: messages,
      status: MentorStatus.streaming,
      error: null,
      references: const [],
      contextPhase: MentorContextPhase.selecting,
      contextError: null,
    );
    final targetIndex = messages.length - 1;
    var terminalReceived = false;
    Stream<SseEvent> stream;
    try {
      stream = scope == null
          ? ref.read(mentorSseConnectProvider)(
              normalized,
              contentId: legacyContentId,
            )
          : ref.read(mentorContextualSseConnectProvider)(
              normalized,
              contentId: contextualContentId,
              contextSnapshotId: contextSnapshotId,
            );
    } on Object catch (error) {
      _finishStreamError(error, targetIndex: targetIndex, done: done);
      return done.future;
    }
    _sub = stream.listen(
      (event) {
        if (!_isCurrent(generation) || terminalReceived) return;
        final terminal = parseMentorTerminal(event);
        if (terminal != null) {
          terminalReceived = true;
          final pruned = _pruneEmptyMentorBubble(state.messages, targetIndex);
          if (terminal.status == MentorTerminalStatus.done) {
            state = state.copyWith(
              messages: pruned,
              status: MentorStatus.idle,
              error: null,
              committedSnapshotId: null,
            );
            _clearRetryMetadata();
            _applyPendingContextDefaults();
          } else {
            state = state.copyWith(
              messages: pruned,
              status: _hasMentorText(state.messages, targetIndex)
                  ? MentorStatus.partial
                  : MentorStatus.failed,
              error: _terminalErrorMessage(terminal),
            );
          }
          if (!done.isCompleted) done.complete();
          return;
        }
        if (event.event == 'references') {
          state = state.copyWith(references: _parseReferences(event.data));
          return;
        }
        if (event.event != 'token' || state.messages.length <= targetIndex) {
          return;
        }
        final updated = [...state.messages];
        updated[targetIndex] = updated[targetIndex].append(event.data);
        state = state.copyWith(
          messages: updated,
          status: MentorStatus.streaming,
        );
      },
      onError: (Object error) {
        if (!_isCurrent(generation) || terminalReceived) return;
        terminalReceived = true;
        _finishStreamError(error, targetIndex: targetIndex, done: done);
      },
      onDone: () {
        if (!_isCurrent(generation)) return;
        if (terminalReceived) {
          if (!done.isCompleted) done.complete();
          return;
        }
        terminalReceived = true;
        final pruned = _pruneEmptyMentorBubble(state.messages, targetIndex);
        if (scope == null) {
          state = state.copyWith(
            messages: pruned,
            status: MentorStatus.idle,
            error: null,
          );
          _clearRetryMetadata();
        } else {
          state = state.copyWith(
            messages: pruned,
            status: MentorStatus.partial,
            error: '답변이 완료되기 전에 연결이 종료됐어요. 받은 내용은 그대로 두었어요.',
          );
        }
        if (!done.isCompleted) done.complete();
      },
      cancelOnError: true,
    );
    return done.future;
  }

  Future<void> retry() {
    if (state.status == MentorStatus.streaming) {
      return _inFlight?.future ?? Future.value();
    }
    final question = _lastQuestion;
    if (question == null) return Future.value();
    return _sendStream(
      question,
      legacyContentId: _lastLegacyContentId,
      contextualContentId: _lastContextualContentId,
      contextSnapshotId: _lastContextSnapshotId,
      usedContextFields: _lastUsedContextFields,
    );
  }

  List<MentorContextOption> _contextOptions(
    MentorContextEvidence evidence, {
    required bool includeCurrentCode,
    required bool includeReviewSummary,
  }) => [
    const MentorContextOption(
      id: 'current_content',
      available: true,
      selected: true,
    ),
    MentorContextOption(
      id: 'current_code',
      available: evidence.currentCode != null,
      selected: includeCurrentCode && evidence.currentCode != null,
      unavailableReason: evidence.currentCode == null
          ? '현재 편집기 코드가 없어요.'
          : null,
    ),
    MentorContextOption(
      id: 'recent_errors',
      available: evidence.session?.stderr.trim().isNotEmpty == true,
      selected: false,
      unavailableReason: evidence.session == null
          ? '저장된 실행 결과가 없어요.'
          : evidence.session!.stderr.trim().isEmpty
          ? '저장된 최근 오류가 없어요.'
          : null,
    ),
    MentorContextOption(
      id: 'recent_output',
      available: evidence.session != null,
      selected: false,
      unavailableReason: evidence.session == null ? '저장된 실행 결과가 없어요.' : null,
    ),
    MentorContextOption(
      id: 'review_summary',
      available: evidence.review != null,
      selected: includeReviewSummary && evidence.review != null,
      unavailableReason: evidence.review == null ? '현재 실행과 연결된 리뷰가 없어요.' : null,
    ),
  ];

  Map<String, Object?> _requestContext(
    MentorContextEvidence evidence,
    Set<String> selected,
  ) {
    final context = <String, Object?>{};
    if (selected.contains('current_code') && evidence.currentCode != null) {
      context['current_code'] = evidence.currentCode;
    }
    final session = evidence.session;
    if (selected.contains('recent_errors') && session != null) {
      context['recent_errors'] = session.stderr
          .split('\n')
          .where((line) => line.isNotEmpty)
          .toList(growable: false);
    }
    if (selected.contains('recent_output') && session != null) {
      context['recent_output'] = {
        'stdout': session.stdout,
        'stderr': session.stderr,
        'truncated': session.truncated,
      };
    }
    final review = evidence.review;
    if (selected.contains('review_summary') && review != null) {
      context['review_summary'] = {
        'confidence': review.confidence,
        'strengths': review.strengths,
        'improvements': review.improvements.map(_issueJson).toList(),
        'security': review.security.map(_issueJson).toList(),
      };
    }
    return Map.unmodifiable(context);
  }

  Map<String, Object?> _issueJson(ReviewIssue issue) => {
    'message': issue.message,
    if (issue.line != null) 'line': issue.line,
    'severity': issue.severity,
  };

  void _resetOneRequestSelections() {
    state = state.copyWith(
      contextOptions: state.contextOptions
          .map(
            (option) => _oneRequestFields.contains(option.id)
                ? option.copyWith(selected: false)
                : option,
          )
          .toList(growable: false),
    );
  }

  bool get _mustDeferContextDefaults =>
      _contextInitialized &&
      (state.status == MentorStatus.streaming ||
          state.status == MentorStatus.partial ||
          state.status == MentorStatus.busy ||
          state.status == MentorStatus.failed ||
          state.contextPhase == MentorContextPhase.loadingPreview ||
          state.contextPhase == MentorContextPhase.committing ||
          state.contextPhase == MentorContextPhase.failed);

  void _applyPendingContextDefaults() {
    final scope = scopeKey;
    final pending = _pendingContextDefaults;
    if (scope == null || pending == null) return;
    _pendingContextDefaults = null;
    state = state.copyWith(
      contextOptions: _contextOptions(
        ref.read(mentorContextEvidenceProvider(scope)),
        includeCurrentCode: pending.includeCurrentCode,
        includeReviewSummary: pending.includeReviewSummary,
      ),
    );
  }

  bool _scopeIsCurrent(MentorScopeKey scope) =>
      ref.read(mentorScopeValidatorProvider(scope))();

  void _contextFailure(String message) {
    state = state.copyWith(
      contextPhase: MentorContextPhase.failed,
      contextError: message,
    );
  }

  String _contextErrorMessage(Object error) => switch (error) {
    ApiException(:final message) => message,
    FormatException() => '맥락 응답 형식을 확인하지 못했어요.',
    _ => '학습 맥락을 준비하지 못했어요. 다시 시도해 주세요.',
  };

  List<MentorReference> _parseReferences(String data) {
    try {
      final decoded = jsonDecode(data);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(MentorReference.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  List<ChatMessage> _pruneEmptyMentorBubble(
    List<ChatMessage> messages,
    int targetIndex,
  ) {
    if (targetIndex < messages.length &&
        !messages[targetIndex].fromUser &&
        messages[targetIndex].text.isEmpty) {
      return [...messages]..removeAt(targetIndex);
    }
    return messages;
  }

  bool _hasMentorText(List<ChatMessage> messages, int targetIndex) =>
      targetIndex < messages.length &&
      !messages[targetIndex].fromUser &&
      messages[targetIndex].text.isNotEmpty;

  void _finishStreamError(
    Object error, {
    required int targetIndex,
    required Completer<void> done,
  }) {
    final hasText = _hasMentorText(state.messages, targetIndex);
    final isKill = error is ApiException && error.isKillSwitch;
    final isBusy = error is ApiException && error.isMentorBusy;
    final status = hasText
        ? MentorStatus.partial
        : isKill
        ? MentorStatus.killSwitch
        : isBusy
        ? MentorStatus.busy
        : error is ApiException
        ? MentorStatus.failed
        : MentorStatus.partial;
    state = state.copyWith(
      messages: _pruneEmptyMentorBubble(state.messages, targetIndex),
      status: status,
      error: _streamErrorMessage(error),
    );
    if (!done.isCompleted) done.complete();
  }

  String _streamErrorMessage(Object error) {
    if (error is ApiException && error.isMentorBusy) {
      return '멘토가 다른 답변을 처리 중이에요. 잠시 후 다시 시도해 주세요.';
    }
    if (error is TimeoutException) {
      return '답변 생성 시간이 초과됐어요. 받은 내용은 그대로 두었어요.';
    }
    return error is ApiException ? error.message : '연결이 끊겼어요';
  }

  String _terminalErrorMessage(MentorTerminal terminal) =>
      switch (terminal.code) {
        'AI_TIMEOUT' => '답변 생성 시간이 초과됐어요. 받은 내용은 그대로 두었어요.',
        'MALFORMED_TERMINAL' => '답변 완료 상태를 확인하지 못했어요. 다시 시도해 주세요.',
        _ =>
          terminal.message?.trim().isNotEmpty == true
              ? terminal.message!.trim()
              : '답변을 완료하지 못했어요. 다시 시도해 주세요.',
      };

  bool _isCurrent(int generation) => !_disposed && generation == _generation;

  void _completeInFlight() {
    final active = _inFlight;
    if (active != null && !active.isCompleted) active.complete();
  }

  void _clearRetryMetadata() {
    _lastQuestion = null;
    _lastLegacyContentId = null;
    _lastContextualContentId = null;
    _lastContextSnapshotId = null;
    _lastUsedContextFields = const [];
  }

  void _resetForOwnershipChange() {
    _generation += 1;
    unawaited(_sub?.cancel());
    _completeInFlight();
    _clearRetryMetadata();
    _pendingContextDefaults = null;
    _contextInitialized = false;
    state = const MentorState();
  }
}

final mentorControllerProvider =
    NotifierProvider<MentorController, MentorState>(MentorController.new);

final contextualMentorControllerProvider =
    NotifierProvider.family<MentorController, MentorState, MentorScopeKey>(
      MentorController.new,
    );
