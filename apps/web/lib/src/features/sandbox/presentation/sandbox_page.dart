import 'dart:async';

import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../analytics/analytics_contract.dart';
import '../../../providers/api_providers.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/state/auth_state.dart';
import '../../content/application/mission_content_controller.dart';
import '../../common/application/track_catalog.dart';
import '../../dashboard/application/current_mission_controller.dart';
import '../../mission/state/mission_workspace_key.dart';
import '../../review/application/review_controller.dart';
import '../../review/presentation/review_panel.dart';
import '../../review/state/review_state.dart';
import '../application/run_controller.dart';
import '../application/sandbox_funnel_analytics.dart';
import '../application/sandbox_workspace_controller.dart';
import '../application/sandbox_workspace_retention.dart';
import '../state/run_state.dart';
import '../state/sandbox_workspace_context.dart';
import 'monaco_editor_view.dart';
import 'sandbox_layout.dart';

const _kLanguages = SandboxLanguage.values;

class SandboxPage extends ConsumerStatefulWidget {
  const SandboxPage({super.key, this.workspaceKey});

  /// Verified canonical workspace. Legacy `/sandbox` keeps this null.
  final MissionWorkspaceKey? workspaceKey;

  @override
  ConsumerState<SandboxPage> createState() => _SandboxPageState();
}

class _SandboxPageState extends ConsumerState<SandboxPage> {
  final GlobalKey<MonacoEditorViewState> _editorKey =
      GlobalKey<MonacoEditorViewState>();
  final GlobalKey<SandboxLayoutState> _layoutKey =
      GlobalKey<SandboxLayoutState>();
  var _capsuleExpanded = true;
  var _loadScheduled = false;
  var _restoreScheduled = false;
  String? _pageOwnerKey;
  MissionContentRetentionController? _missionContentRetention;
  SandboxWorkspaceRetentionController? _sandboxRetention;

  @override
  void initState() {
    super.initState();
    if (widget.workspaceKey != null) {
      _pageOwnerKey = ref.read(currentMissionOwnerKeyProvider);
    }
    _scheduleCanonicalLoad();
  }

  @override
  void didUpdateWidget(covariant SandboxPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workspaceKey == widget.workspaceKey) return;
    final oldKey = oldWidget.workspaceKey;
    if (oldKey != null) {
      ref.read(sandboxWorkspaceRetentionProvider.notifier).deactivate(oldKey);
      ref.read(missionContentRetentionProvider.notifier).deactivate(oldKey);
    }
    _loadScheduled = false;
    _restoreScheduled = false;
    _pageOwnerKey = widget.workspaceKey == null
        ? null
        : ref.read(currentMissionOwnerKeyProvider);
    _scheduleCanonicalLoad();
  }

  @override
  void dispose() {
    final key = widget.workspaceKey;
    if (key != null) {
      // ConsumerState.ref is no longer safe once unmount starts. Keep the
      // owner-aware retention coordinator captured while mounted, matching
      // ContentPage's canonical lifecycle.
      _missionContentRetention?.deactivate(key);
      _sandboxRetention?.deactivate(key);
    }
    super.dispose();
  }

  void _scheduleCanonicalLoad() {
    final key = widget.workspaceKey;
    if (key == null || _loadScheduled) return;
    final scheduledOwner = ref.read(currentMissionOwnerKeyProvider);
    _loadScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_isScheduledWorkspaceCurrent(key, scheduledOwner)) {
        if (widget.workspaceKey == key) _loadScheduled = false;
        return;
      }
      _sandboxRetention = ref.read(sandboxWorkspaceRetentionProvider.notifier);
      _sandboxRetention!.activate(key);
      _missionContentRetention = ref.read(
        missionContentRetentionProvider.notifier,
      );
      _missionContentRetention!.activate(key);
      unawaited(
        ref.read(missionContentControllerProvider(key).notifier).load(),
      );
    });
  }

  void _scheduleRestore(MissionWorkspaceKey key) {
    if (_restoreScheduled) return;
    final scheduledOwner = ref.read(currentMissionOwnerKeyProvider);
    _restoreScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_isScheduledWorkspaceCurrent(key, scheduledOwner)) {
        if (widget.workspaceKey == key) _restoreScheduled = false;
        return;
      }
      unawaited(ref.read(runControllerFamilyProvider(key).notifier).restore());
    });
  }

  bool _isScheduledWorkspaceCurrent(
    MissionWorkspaceKey key,
    String? scheduledOwner,
  ) {
    if (widget.workspaceKey != key ||
        ref.read(currentMissionOwnerKeyProvider) != scheduledOwner) {
      return false;
    }
    final mission = ref.read(currentMissionControllerProvider).mission;
    if (mission?.outcome != CurrentMissionOutcome.available) return false;
    return mission!.tasks
            .where(
              (task) =>
                  task.taskId == key.taskId && task.contentId == key.contentId,
            )
            .length ==
        1;
  }

  @override
  Widget build(BuildContext context) {
    final key = widget.workspaceKey;
    return key == null ? _buildLegacy(context) : _buildCanonical(context, key);
  }

  Widget _buildLegacy(BuildContext context) {
    final draftProvider = sandboxWorkspaceControllerProvider(null);
    final runProvider = runControllerFamilyProvider(null);
    final draft = ref.watch(draftProvider);
    final run = ref.watch(runProvider);
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DpPageHeader(
            title: '실습 샌드박스',
            description: '코드를 작성하고 바로 실행해 봅니다',
            actions: [
              _LanguageDropdown(
                language: draft.language,
                enabled: true,
                onChanged: (language) =>
                    ref.read(draftProvider.notifier).selectLanguage(language),
              ),
              FilledButton(
                onPressed: run is RunRunning || draft.language == null
                    ? null
                    : () => unawaited(
                        ref
                            .read(runProvider.notifier)
                            .run(draft.code, draft.language!.wireName),
                      ),
                child: const Text('실행'),
              ),
            ],
          ),
          Expanded(
            child: _workspaceLayout(
              key: null,
              draft: draft,
              run: run,
              runProvider: runProvider,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCanonical(BuildContext context, MissionWorkspaceKey key) {
    final ownerKey = ref.watch(currentMissionOwnerKeyProvider);
    if (ownerKey != _pageOwnerKey) {
      _pageOwnerKey = ownerKey;
      _loadScheduled = false;
      _restoreScheduled = false;
    }
    final missionState = ref.watch(currentMissionControllerProvider);
    final mission = missionState.mission;
    if (mission == null) {
      if (missionState.isLoading || missionState.failureMessage == null) {
        return const Scaffold(body: DpLoading(label: '현재 미션을 다시 확인하는 중'));
      }
      return _missionRecovery(
        title: '현재 미션을 불러오지 못했어요',
        message: '${missionState.failureMessage!} 작성한 코드는 보존했어요.',
      );
    }
    final matchingTasks = mission.tasks
        .where(
          (task) =>
              task.taskId == key.taskId && task.contentId == key.contentId,
        )
        .toList(growable: false);
    if (mission.outcome != CurrentMissionOutcome.available ||
        matchingTasks.length != 1) {
      return _missionRecovery(
        title: '현재 미션과 실습 연결을 다시 확인해 주세요',
        message: '서버가 확인한 오늘의 미션과 이 실습이 더 이상 일치하지 않아 실행을 멈췄어요.',
      );
    }
    final task = matchingTasks.single;
    // Owner switches revalidate Today before any owner-scoped content fetch.
    _scheduleCanonicalLoad();
    final contentState = ref.watch(missionContentControllerProvider(key));
    final content = contentState.content;
    if (content == null) {
      if (contentState.isLoading || contentState.failureMessage == null) {
        return const Scaffold(body: DpLoading(label: '실습 맥락을 준비하는 중'));
      }
      return Scaffold(
        body: DpError(
          title: '실습 맥락을 불러오지 못했어요',
          message: '${contentState.failureMessage!} 편집 내용은 그대로예요.',
          onRetry: () => unawaited(
            ref
                .read(missionContentControllerProvider(key).notifier)
                .load(force: true),
          ),
        ),
      );
    }

    final workspaceContext = SandboxWorkspaceContext.resolve(
      workspaceKey: key,
      content: content,
      taskTitle: task.title,
    );
    final draftProvider = sandboxWorkspaceControllerProvider(key);
    final draft = ref.watch(draftProvider);
    if (draft.context == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || widget.workspaceKey != key) return;
        ref.read(draftProvider.notifier).configure(workspaceContext);
      });
      return const Scaffold(body: DpLoading(label: '실습 편집기를 준비하는 중'));
    }
    _scheduleRestore(key);

    final runProvider = runControllerFamilyProvider(key);
    final run = ref.watch(runProvider);
    final review = ref.watch(reviewControllerFamilyProvider(key));
    final hasCurrentReview = _hasCurrentReview(run, review);
    _scheduleFunnelCaptures(key);
    final topMaxHeight = MediaQuery.sizeOf(context).height * 0.52;
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: topMaxHeight),
              child: SingleChildScrollView(
                key: const ValueKey('sandbox-context-scroll'),
                padding: const EdgeInsets.all(DpSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DpMissionHeader(
                      eyebrow: mission.weekNum == null
                          ? '오늘의 미션 · 실습'
                          : '${mission.weekNum}주차 · 오늘의 미션 · 실습',
                      title: workspaceContext.taskTitle,
                      why:
                          '${workspaceContext.contentTitle}에서 배운 내용을 직접 실행합니다.',
                      completionCriterion: '실행 결과를 확인하고 코드 리뷰로 이어갑니다',
                      progressValue: content.progress.scrollPct
                          .clamp(0, 1)
                          .toDouble(),
                      progressLabel: '콘텐츠 학습 진행률',
                      variant: DpMissionHeaderVariant.compact,
                    ),
                    const SizedBox(height: DpSpacing.md),
                    DpContextCapsule(
                      name: '이번 실습 맥락',
                      mode: _capsuleExpanded
                          ? DpContextCapsuleMode.expanded
                          : DpContextCapsuleMode.collapsed,
                      onDisclosurePressed: () =>
                          setState(() => _capsuleExpanded = !_capsuleExpanded),
                      fields: [
                        DpContextFieldViewModel(
                          id: 'task',
                          label: '현재 과제',
                          valueSummary: workspaceContext.taskTitle,
                          source: '오늘의 미션',
                          sensitivity: DpContextSensitivity.low,
                          inclusion: DpContextInclusion.included,
                        ),
                        DpContextFieldViewModel(
                          id: 'content',
                          label: '현재 단원',
                          valueSummary: workspaceContext.contentTitle,
                          source: '학습 콘텐츠',
                          sensitivity: DpContextSensitivity.low,
                          inclusion: DpContextInclusion.included,
                        ),
                        DpContextFieldViewModel(
                          id: 'runtime',
                          label: '실행 환경',
                          valueSummary: draft.language?.wireName ?? '선택 필요',
                          source:
                              trackLabels[workspaceContext.track] ?? '학습 트랙',
                          sensitivity: DpContextSensitivity.low,
                          inclusion: DpContextInclusion.included,
                        ),
                        DpContextFieldViewModel(
                          id: 'starter',
                          label: 'starter 출처',
                          valueSummary: _starterSummary(
                            workspaceContext,
                            draft.language,
                          ),
                          source: 'Sandbox 지원 계약',
                          sensitivity: DpContextSensitivity.low,
                          inclusion: DpContextInclusion.included,
                        ),
                      ],
                    ),
                    const SizedBox(height: DpSpacing.md),
                    Wrap(
                      spacing: DpSpacing.md,
                      runSpacing: DpSpacing.sm,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _LanguageDropdown(
                          language: draft.language,
                          enabled: workspaceContext.canSelectLanguage,
                          onChanged: (language) => ref
                              .read(draftProvider.notifier)
                              .selectLanguage(language),
                        ),
                        if (draft.draftNotice != null)
                          Semantics(
                            liveRegion: true,
                            child: Text(draft.draftNotice!),
                          ),
                      ],
                    ),
                    const SizedBox(height: DpSpacing.md),
                    if (!hasCurrentReview)
                      DpNextActionBand(
                        actionId: _nextAction(run),
                        label: _nextActionLabel(run),
                        expectedOutcome: _nextActionOutcome(run),
                        state: _nextActionState(
                          run,
                          language: draft.language,
                          context: workspaceContext,
                        ),
                        pendingLabel: '실행 상태를 확인하는 중',
                        retryLabel: '다시 실행',
                        disabledReason: draft.language == null
                            ? workspaceContext.starterLabel
                            : null,
                        onPressed: draft.language == null
                            ? null
                            : (_) {
                                if (run is RunCompleted) {
                                  _layoutKey.currentState?.showReview();
                                  return;
                                }
                                unawaited(
                                  ref
                                      .read(runProvider.notifier)
                                      .run(
                                        draft.code,
                                        draft.language!.wireName,
                                        codeBlockId:
                                            workspaceContext.codeBlockId,
                                      ),
                                );
                              },
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: _workspaceLayout(
                key: key,
                draft: draft,
                run: run,
                runProvider: runProvider,
                reviewNextAction: hasCurrentReview
                    ? DpNextActionBand(
                        actionId: 'next_mission',
                        label: '다음 미션으로',
                        expectedOutcome: '오늘의 학습 경로에서 다음 미션을 확인합니다.',
                        state: DpNextActionState.ready,
                        onPressed: (_) => _openCanonicalToday(key),
                      )
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _missionRecovery({required String title, required String message}) =>
      Scaffold(
        body: DpError(
          title: title,
          message: message,
          onRetry: () => unawaited(
            ref
                .read(currentMissionControllerProvider.notifier)
                .invalidateAndRefetch(),
          ),
        ),
      );

  Widget _workspaceLayout({
    required MissionWorkspaceKey? key,
    required SandboxWorkspaceState draft,
    required RunState run,
    required NotifierProvider<RunController, RunState> runProvider,
    Widget? reviewNextAction,
  }) => SandboxLayout(
    key: _layoutKey,
    onEditorVisible: () => _editorKey.currentState?.layout(),
    onReviewVisibilityChanged: key == null ? null : _onReviewVisibilityChanged,
    editor: _editorPane(key: key, draft: draft),
    log: _LogPane(
      run: run,
      onRecover: run.sandboxSessionId == null
          ? null
          : () => unawaited(ref.read(runProvider.notifier).retryRecovery()),
    ),
    review: ReviewPanel(
      workspaceKey: key,
      nextAction: reviewNextAction,
      onRequest: () {
        final sessionId = ref.read(runProvider).sandboxSessionId;
        final message = sessionId == null
            ? '먼저 코드를 실행하세요.'
            : '실행이 끝난 뒤 리뷰를 확인할 수 있어요.';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      },
    ),
  );

  Widget _editorPane({
    required MissionWorkspaceKey? key,
    required SandboxWorkspaceState draft,
  }) {
    final language = draft.language;
    if (language == null) {
      final context = draft.context;
      return DpEmpty(
        key: const ValueKey('sandbox-runtime-neutral'),
        icon: DpIcons.sandboxOff,
        title: context?.starterKind == SandboxStarterKind.unsupported
            ? '지원하지 않는 실행 환경이에요'
            : '실행 언어를 선택해 주세요',
        message: context?.starterKind == SandboxStarterKind.unsupported
            ? '편집기와 실행기는 지원 runtime이 확인될 때까지 열지 않습니다.'
            : '위에서 JAVA, NODE 또는 PYTHON을 선택하면 편집기를 준비합니다.',
      );
    }
    return MonacoEditorView(
      key: _editorKey,
      initialCode: draft.code,
      language: language,
      onChanged: (value) => ref
          .read(sandboxWorkspaceControllerProvider(key).notifier)
          .updateCode(value),
    );
  }

  void _onReviewVisibilityChanged(bool visible) {
    if (!visible) return;
    final key = widget.workspaceKey;
    if (key != null) _scheduleFunnelCaptures(key);
  }

  bool _hasCurrentReview(RunState run, ReviewState review) =>
      review is ReviewLoaded &&
      run is RunTerminal &&
      review.sandboxSessionId == run.sandboxSessionId;

  void _scheduleFunnelCaptures(MissionWorkspaceKey key) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.workspaceKey != key || !_isCurrentRoute) return;
      _captureFirstPractice(key);
      _captureContextualReview(key);
    });
  }

  void _captureFirstPractice(MissionWorkspaceKey key) {
    final run = ref.read(runControllerFamilyProvider(key));
    final runId = persistedCompletedRunId(run);
    if (runId == null) return;
    final identity = _verifiedIdentity(key);
    if (identity == null) return;
    final store = ref.read(sandboxFunnelStoreProvider);
    try {
      if (!store.claimFirstPractice(
        userId: identity.userId,
        workspaceKey: key,
        runId: runId,
      )) {
        return;
      }
      ref.read(journeyAnalyticsProvider).capture('first_practice_succeeded', {
        'user_id': identity.userId,
        'path_id': identity.pathId,
        'task_id': key.taskId,
        'content_id': key.contentId,
        'run_id': runId,
        'first_successful_run': true,
      });
    } on Object {
      // Analytics and browser storage are never allowed to block the run UI.
    }
  }

  void _captureContextualReview(MissionWorkspaceKey key) {
    if (_layoutKey.currentState?.isReviewVisible != true) return;
    final run = ref.read(runControllerFamilyProvider(key));
    final review = ref.read(reviewControllerFamilyProvider(key));
    final reviewId = contextualReviewId(run: run, review: review);
    final identity = _verifiedIdentity(key);
    if (reviewId == null || identity == null || run is! RunCompleted) return;
    final store = ref.read(sandboxFunnelStoreProvider);
    try {
      if (!store.claimContextualReview(
        userId: identity.userId,
        workspaceKey: key,
        sandboxSessionId: run.sandboxSessionId,
        reviewId: reviewId,
      )) {
        return;
      }
      ref.read(journeyAnalyticsProvider).capture('contextual_review_viewed', {
        'user_id': identity.userId,
        'task_id': key.taskId,
        'review_id': reviewId,
        'approved_context_field_count': run.approvedContextFieldCount,
        'next_action_outcome': 'next_mission',
        'first_view': true,
      });
    } on Object {
      // SDK/scheduler failures are isolated from review rendering/navigation.
    }
  }

  ({String userId, int pathId})? _verifiedIdentity(MissionWorkspaceKey key) {
    final ownerKey = ref.read(currentMissionOwnerKeyProvider);
    if (!isPlatformUserId(ownerKey)) return null;
    final auth = ref.read(authControllerProvider);
    final mission = ref.read(currentMissionControllerProvider).mission;
    if (auth is! AuthAuthenticated ||
        ownerKey != auth.user.id ||
        mission?.outcome != CurrentMissionOutcome.available ||
        mission?.pathId == null) {
      return null;
    }
    final matches = mission!.tasks.where(
      (task) => task.taskId == key.taskId && task.contentId == key.contentId,
    );
    if (matches.length != 1) return null;
    return (userId: auth.user.id, pathId: mission.pathId!);
  }

  void _openCanonicalToday(MissionWorkspaceKey key) {
    final identity = _verifiedIdentity(key);
    if (identity == null) return;
    context.go('/path/${identity.pathId}/today');
  }

  bool get _isCurrentRoute => ModalRoute.of(context)?.isCurrent ?? true;

  String _nextAction(RunState run) =>
      run is RunCompleted ? 'open_review' : 'run_code';

  String _starterSummary(
    SandboxWorkspaceContext context,
    SandboxLanguage? selectedLanguage,
  ) => switch (context.starterKind) {
    SandboxStarterKind.generic => '${context.language!.wireName} 일반 템플릿',
    SandboxStarterKind.selectionRequired =>
      selectedLanguage == null
          ? 'runtime 선택 후 일반 템플릿'
          : '${selectedLanguage.wireName} 일반 템플릿',
    SandboxStarterKind.unsupported => '사용 가능한 starter 없음',
  };

  String _nextActionLabel(RunState run) =>
      run is RunCompleted ? '리뷰 확인' : '코드 실행';

  String _nextActionOutcome(RunState run) => run is RunCompleted
      ? '이 실행 세션과 연결된 코드 리뷰를 확인합니다.'
      : '현재 편집 코드가 선택한 runtime에서 실행되고 결과가 아래에 보입니다.';

  DpNextActionState _nextActionState(
    RunState run, {
    required SandboxLanguage? language,
    required SandboxWorkspaceContext context,
  }) {
    if (language == null || !context.canSelectLanguage) {
      return DpNextActionState.disabled;
    }
    return switch (run) {
      RunRunning() => DpNextActionState.pending,
      RunCompleted() => DpNextActionState.ready,
      RunFailed() ||
      RunKilled() ||
      RunTimedOut() ||
      RunUnavailable() ||
      RunBusy() ||
      RunTransportAborted() => DpNextActionState.retry,
      RunIdle() || RunDone() => DpNextActionState.ready,
    };
  }
}

class _LanguageDropdown extends StatelessWidget {
  const _LanguageDropdown({
    required this.language,
    required this.enabled,
    required this.onChanged,
  });

  final SandboxLanguage? language;
  final bool enabled;
  final ValueChanged<SandboxLanguage> onChanged;

  @override
  Widget build(BuildContext context) => DropdownButton<SandboxLanguage>(
    key: const Key('sandbox_language_dropdown'),
    value: language,
    hint: const Text('실행 언어 선택'),
    items: _kLanguages
        .map(
          (candidate) => DropdownMenuItem(
            value: candidate,
            child: Text(candidate.wireName),
          ),
        )
        .toList(growable: false),
    onChanged: enabled
        ? (value) {
            if (value != null) onChanged(value);
          }
        : null,
  );
}

class _LogPane extends StatelessWidget {
  const _LogPane({required this.run, this.onRecover});

  final RunState run;
  final VoidCallback? onRecover;

  @override
  Widget build(BuildContext context) {
    final status = _statusMessage(run);
    return Container(
      color: context.dpColors.codeLogBg,
      padding: const EdgeInsets.all(DpSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (status != null)
            Semantics(
              liveRegion: run is RunRunning || run is RunTransportAborted,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      status,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.dpColors.codeText,
                      ),
                    ),
                  ),
                  if (run is RunTransportAborted && onRecover != null)
                    TextButton(
                      onPressed: onRecover,
                      child: const Text('상태 복구'),
                    ),
                ],
              ),
            ),
          if (status != null) const SizedBox(height: DpSpacing.sm),
          Expanded(
            child: run.logs.isEmpty
                ? Text(
                    '실행 결과가 여기에 표시됩니다.',
                    style: DpTypography.code.copyWith(
                      color: context.dpColors.codeText,
                    ),
                  )
                : ListView.builder(
                    itemCount: run.logs.length,
                    itemBuilder: (context, index) => Text(
                      run.logs[index],
                      style: DpTypography.code.copyWith(
                        color: context.dpColors.codeText,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  String? _statusMessage(RunState run) => switch (run) {
    RunIdle() => null,
    RunRunning(:final status, :final sandboxSessionId) => switch (status) {
      SandboxSessionStatus.allocating =>
        sandboxSessionId == null
            ? '실행을 접수하는 중입니다.'
            : '세션 $sandboxSessionId · 실행 환경을 할당하는 중입니다.',
      SandboxSessionStatus.running =>
        '세션 ${sandboxSessionId ?? '-'} · 실행 중입니다.',
      _ => '실행 상태를 복구하는 중입니다.',
    },
    RunDone() => '기존 실행 스트림이 종료되었습니다.',
    RunCompleted() =>
      '세션 ${run.sandboxSessionId} · 실행 완료${run.truncated ? ' · 출력 일부만 표시' : ''}',
    RunFailed() =>
      '세션 ${run.sandboxSessionId} · 실행 실패${run.truncated ? ' · 출력 일부만 표시' : ''}',
    RunKilled() => '세션 ${run.sandboxSessionId} · 실행 중단',
    RunTimedOut() =>
      '세션 ${run.sandboxSessionId} · 시간 초과${run.truncated ? ' · 출력 일부만 표시' : ''}',
    RunUnavailable(:final message) => message ?? '실행 서비스를 사용할 수 없습니다.',
    RunBusy(:final message) => message ?? '현재 실행 대기열이 가득 찼습니다.',
    RunTransportAborted(:final message) => message,
  };
}
