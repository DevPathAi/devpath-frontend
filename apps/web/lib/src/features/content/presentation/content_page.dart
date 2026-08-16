import 'dart:async';

import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../providers/api_providers.dart';
import '../../ads/presentation/ad_slot_widget.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/state/auth_state.dart';
import '../application/content_controller.dart';
import '../application/content_progress_tracker.dart';
import '../application/mission_content_controller.dart';
import '../state/content_state.dart';
import '../../dashboard/application/dashboard_controller.dart';
import '../../dashboard/application/current_mission_controller.dart';
import '../../mission/state/mission_workspace_key.dart';
import '../../path/application/path_controller.dart';
import '../../support/presentation/supportable_error.dart';

class ContentPage extends ConsumerStatefulWidget {
  const ContentPage({super.key, required this.contentId}) : workspaceKey = null;

  const ContentPage.mission({super.key, required this.workspaceKey})
    : contentId = '';

  final String contentId;
  final MissionWorkspaceKey? workspaceKey;

  @override
  ConsumerState<ContentPage> createState() => _ContentPageState();
}

class _ContentPageState extends ConsumerState<ContentPage>
    with WidgetsBindingObserver {
  final _scrollController = ScrollController();
  // _scrollPct의 헤더 높이 보정에 쓴다 — DpPageHeader가 CustomScrollView의
  // 첫 sliver로 실려 있어 _scrollController가 헤더+본문 전체 스크롤 범위를
  // 관측한다(Task 10). 이 키로 헤더가 실제로 차지하는 박스 높이를 재서 서버로
  // 보내는 진행률에서 빼낸다.
  final _headerKey = GlobalKey();
  ContentController? _contentController;
  MissionContentController? _lastMissionContentController;
  MissionContentRetentionController? _missionRetentionController;
  late final ApiClient _apiClient;
  Timer? _dwellTimer;
  ContentProgressTracker? _tracker;
  String? _trackedContentKey;
  ContentState? _latestLegacyState;
  LearningContent? _latestContent;
  int _dwellSec = 0;
  bool _posting = false;
  ContentProgressFlush? _failedFlush;
  bool _missionStartedCaptured = false;
  bool _missionStartedScheduled = false;
  bool _contentLoadScheduled = false;
  String? _pageOwnerKey;
  var _pageEpoch = 0;

  /// 마지막으로 실측에 성공한 스크롤 진행률. dispose 시점에는 스크롤 위치를
  /// 잴 수 없어(자식 먼저 unmount → `hasClients == false`) 이 값이 필요하다.
  double? _lastObservedScrollPct;

  @override
  void initState() {
    super.initState();
    if (widget.workspaceKey != null) {
      _pageOwnerKey = ref.read(currentMissionOwnerKeyProvider);
    }
    _bindController();
    _apiClient = ref.read(apiClientProvider);
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_maybeFlushProgress);
    _dwellTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_isCurrentRoute) return;
      final content = _readContent();
      if (content == null || content.progress.completed) return;
      _dwellSec++;
      _maybeFlushProgress();
    });
    if (widget.workspaceKey == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadContent());
    }
  }

  @override
  void didUpdateWidget(covariant ContentPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.contentId == widget.contentId &&
        oldWidget.workspaceKey == widget.workspaceKey) {
      return;
    }
    if (oldWidget.workspaceKey case final oldKey?) {
      _missionRetentionController?.deactivate(oldKey);
    }
    _pageEpoch += 1;
    _pageOwnerKey = widget.workspaceKey == null
        ? null
        : ref.read(currentMissionOwnerKeyProvider);
    _resetProgressTracker();
    _missionStartedCaptured = false;
    _missionStartedScheduled = false;
    _contentLoadScheduled = false;
    _bindController();
    if (widget.workspaceKey == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadContent());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _maybeFlushProgress(force: true);
    }
  }

  @override
  void dispose() {
    _flushCachedProgressOnDispose();
    if (widget.workspaceKey case final workspaceKey?) {
      _missionRetentionController?.deactivate(workspaceKey);
    }
    _pageEpoch += 1;
    _dwellTimer?.cancel();
    _scrollController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final workspaceKey = widget.workspaceKey;
    final currentMissionState = workspaceKey == null
        ? null
        : ref.watch(currentMissionControllerProvider);
    final currentOwnerKey = workspaceKey == null
        ? null
        : ref.watch(currentMissionOwnerKeyProvider);
    if (workspaceKey != null && currentOwnerKey != _pageOwnerKey) {
      _synchronizeOwner(currentOwnerKey);
    }
    final missionState = workspaceKey == null
        ? null
        : ref.watch(missionContentControllerProvider(workspaceKey));
    final legacyState = workspaceKey == null
        ? ref.watch(contentControllerProvider)
        : null;
    if (legacyState != null) _latestLegacyState = legacyState;

    final missionBound =
        workspaceKey == null ||
        _missionController(workspaceKey).isBoundTo(currentOwnerKey);
    final content = workspaceKey == null
        ? switch (legacyState) {
            ContentLoaded(:final content) => content,
            _ => null,
          }
        : missionBound
        ? missionState?.content
        : null;
    final initialFailure = workspaceKey == null
        ? switch (legacyState) {
            ContentFailed(:final message) => message,
            _ => null,
          }
        : content == null && missionBound
        ? missionState?.failureMessage
        : null;
    final inlineLoadFailure = workspaceKey != null && content != null
        ? missionState?.failureMessage
        : null;
    final progressFailure = workspaceKey == null
        ? switch (legacyState) {
            ContentLoaded(:final progressError) => progressError,
            _ => null,
          }
        : missionState?.progressFailureMessage;
    final loading =
        !missionBound ||
        (content == null && initialFailure == null) ||
        (workspaceKey == null && legacyState is ContentLoading);

    if (workspaceKey != null &&
        missionBound &&
        missionState?.content == null &&
        missionState?.isLoading == false &&
        missionState?.failureMessage == null &&
        !_contentLoadScheduled) {
      _contentLoadScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _contentLoadScheduled = false;
        _loadContent();
      });
    }

    if (content != null) {
      _latestContent = content;
      _syncTracker(content);
      if (workspaceKey != null && currentMissionState?.mission != null) {
        _scheduleMissionStarted(workspaceKey);
      }
    }

    final c = context.dpColors;
    return Scaffold(
      body: CustomScrollView(
        // 진행률 추적(_scrollPct)이 이 컨트롤러 하나로 헤더+본문 전체 스크롤
        // 범위를 관측한다 — 본문에 별도 스크롤 위젯을 두면 중첩 스크롤이 되어
        // 헤더가 스크롤과 함께 사라지지 않는다.
        controller: _scrollController,
        slivers: [
          SliverToBoxAdapter(
            child: workspaceKey == null
                ? DpPageHeader(
                    key: _headerKey,
                    title: '학습 콘텐츠',
                    description: '읽고 나면 바로 실습으로 이어집니다',
                    actions: [
                      TextButton.icon(
                        key: const ValueKey('content-practice-action'),
                        onPressed: () => context.go('/sandbox'),
                        style: TextButton.styleFrom(
                          backgroundColor: c.accentSoft,
                          foregroundColor: c.primaryText,
                          side: BorderSide(color: c.accentLine),
                        ),
                        icon: const Icon(DpIcons.code),
                        label: const Text('실습'),
                      ),
                    ],
                  )
                : Padding(
                    key: _headerKey,
                    padding: const EdgeInsets.fromLTRB(
                      DpSpacing.lg,
                      DpSpacing.lg,
                      DpSpacing.lg,
                      0,
                    ),
                    child: _MissionContentHeader(
                      workspaceKey: workspaceKey,
                      mission: currentMissionState?.mission,
                      content: content,
                    ),
                  ),
          ),
          if (loading)
            const SliverFillRemaining(hasScrollBody: false, child: DpLoading())
          else if (initialFailure != null)
            SliverFillRemaining(
              hasScrollBody: false,
              child: SupportableError(
                message: initialFailure,
                onRetry: _loadContent,
              ),
            )
          else if (content != null)
            SliverPadding(
              padding: const EdgeInsets.all(DpSpacing.lg),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (inlineLoadFailure != null) ...[
                      _InlineContentError(
                        message: inlineLoadFailure,
                        actionLabel: '콘텐츠 다시 불러오기',
                        onRetry: _posting ? null : _loadContent,
                      ),
                      const SizedBox(height: DpSpacing.md),
                    ],
                    if (progressFailure != null) ...[
                      _InlineContentError(
                        message: progressFailure,
                        actionLabel: '진행률 저장 다시 시도',
                        onRetry:
                            _posting ||
                                (missionState?.progressSubmitting ?? false)
                            ? null
                            : _retryFailedProgress,
                      ),
                      const SizedBox(height: DpSpacing.md),
                    ],
                    WebContentProjection(content: content),
                    if (workspaceKey != null) ...[
                      const SizedBox(height: DpSpacing.xl),
                      DpNextActionBand(
                        actionId: 'open-contextual-sandbox',
                        label: '실습 시작',
                        expectedOutcome: '현재 미션 맥락으로 코드 실습을 시작합니다',
                        state: DpNextActionState.ready,
                        onPressed: (_) {
                          _maybeFlushProgress(force: true);
                          context.push(workspaceKey.sandboxLocation);
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _bindController() {
    final workspaceKey = widget.workspaceKey;
    if (workspaceKey == null) {
      _contentController = ref.read(contentControllerProvider.notifier);
      _lastMissionContentController = null;
      _missionRetentionController = null;
      return;
    }
    _contentController = null;
    _lastMissionContentController = ref.read(
      missionContentControllerProvider(workspaceKey).notifier,
    );
    _missionRetentionController = ref.read(
      missionContentRetentionProvider.notifier,
    );
  }

  MissionContentController _missionController(MissionWorkspaceKey key) {
    final controller = ref.read(missionContentControllerProvider(key).notifier);
    _lastMissionContentController = controller;
    return controller;
  }

  void _loadContent() {
    if (!mounted) return;
    if (widget.workspaceKey case final workspaceKey?) {
      _missionRetentionController?.activate(workspaceKey);
      unawaited(_missionController(workspaceKey).load(force: true));
      return;
    }
    unawaited(_contentController!.load(widget.contentId));
  }

  LearningContent? _readContent() {
    final workspaceKey = widget.workspaceKey;
    if (workspaceKey != null) {
      final ownerKey = ref.read(currentMissionOwnerKeyProvider);
      if (!_missionController(workspaceKey).isBoundTo(ownerKey)) {
        return null;
      }
      return ref.read(missionContentControllerProvider(workspaceKey)).content;
    }
    return switch (ref.read(contentControllerProvider)) {
      ContentLoaded(:final content) => content,
      _ => null,
    };
  }

  void _scheduleMissionStarted(MissionWorkspaceKey workspaceKey) {
    if (_missionStartedCaptured || _missionStartedScheduled) return;
    final pageEpoch = _pageEpoch;
    _missionStartedScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (pageEpoch != _pageEpoch) return;
      _missionStartedScheduled = false;
      if (!mounted || _missionStartedCaptured || _readContent() == null) return;
      final mission = ref.read(currentMissionControllerProvider).mission;
      if (mission?.outcome != CurrentMissionOutcome.available) return;
      final task = mission!.nextTask;
      if (task?.taskId != workspaceKey.taskId ||
          task?.contentId != workspaceKey.contentId ||
          mission.pathId == null ||
          mission.weekNum == null) {
        return;
      }
      final auth = ref.read(authControllerProvider);
      if (auth is! AuthAuthenticated) return;
      _missionStartedCaptured = true;
      ref.read(journeyAnalyticsProvider).capture('first_mission_started', {
        'user_id': auth.user.id,
        'path_id': mission.pathId!,
        'week_num': mission.weekNum!,
        'task_id': workspaceKey.taskId,
        'first_open': true,
      });
    });
  }

  void _syncTracker(LearningContent content) {
    final key = content.slug.isNotEmpty ? content.slug : content.id.toString();
    if (_trackedContentKey == key) {
      if (content.progress.completed) _tracker?.markCompleted();
      return;
    }
    _trackedContentKey = key;
    _dwellSec = content.progress.dwellSec;
    _tracker = ContentProgressTracker(
      initialScrollPct: content.progress.scrollPct,
      initialDwellSec: content.progress.dwellSec,
      completed: content.progress.completed,
    );
  }

  void _resetProgressTracker() {
    _tracker = null;
    _trackedContentKey = null;
    _latestLegacyState = null;
    _latestContent = null;
    _dwellSec = 0;
    _posting = false;
    _failedFlush = null;
    // 다른 콘텐츠로 넘어가면 이전 글의 진행률이 새어나가면 안 된다.
    _lastObservedScrollPct = null;
  }

  void _synchronizeOwner(String? ownerKey) {
    _pageOwnerKey = ownerKey;
    _pageEpoch += 1;
    _resetProgressTracker();
    _missionStartedCaptured = false;
    _missionStartedScheduled = false;
    _contentLoadScheduled = false;
  }

  bool get _isCurrentRoute =>
      mounted && (ModalRoute.of(context)?.isCurrent ?? true);

  void _maybeFlushProgress({bool force = false}) {
    if (!_isCurrentRoute) return;
    if (_posting && widget.workspaceKey == null) return;
    final content = _readContent();
    if (content == null) return;
    _latestContent = content;
    _syncTracker(content);
    final tracker = _tracker;
    if (tracker == null) return;

    final scrollPct = _scrollPct(content.progress.scrollPct);
    final recorded = tracker.record(scrollPct: scrollPct, dwellSec: _dwellSec);
    final flush = force ? recorded ?? tracker.disposeFlush() : recorded;
    if (flush != null) unawaited(_postProgress(flush));
  }

  /// [_scrollController]가 붙는 [CustomScrollView]는 헤더+본문을 함께
  /// 스크롤한다(Task 10) — `pixels`/`maxScrollExtent`를 보정 없이 쓰면 분자·
  /// 분모 양쪽에 헤더 높이(headerH)가 똑같이 더해져, 서버로 보내는 진행률이
  /// 실제(본문 기준)보다 **부풀려진다**(1에 더 가깝게 나온다) — 같은 상수를
  /// 분자·분모에 더하면 원래 비율이 1보다 작을 때 그 비율은 항상 커진다.
  ///
  /// 예: 헤더 80px, 본문만 스크롤하던 옛 구조의 max가 1000px이라 하자.
  /// 본문을 500px 스크롤한 지점은 옛 의미로 pctOld = 500/1000 = 0.5다.
  /// 지금 구조에서 같은 본문 위치는 pixelsNew = 500+80 = 580,
  /// maxNew = 1000+80 = 1080이라 보정 없이 580/1080 ≈ 0.537을 보낸다 —
  /// 0.5가 아니라 그보다 큰 값이다. 끝까지 스크롤(pixelsNew==maxNew)할
  /// 때만 우연히 1.0으로 맞아떨어지고(완료 판정은 안전), 그 전 모든
  /// 중간값은 항상 실제보다 부풀려져 나간다(실측: 헤더 보정 없이 50%
  /// 지점을 스크롤하면 약 0.514가 전송됨 — 아래 회귀 테스트 참조).
  ///
  /// headerH를 [_headerKey]로 실측해 양쪽에서 빼면 옛 의미가 그대로
  /// 복원된다: pctOld = (pixelsNew - headerH) / (maxNew - headerH)
  /// = (580-80)/(1080-80) = 500/1000 = 0.5. 헤더가 아직 레이아웃되지 않아
  /// 높이를 잴 수 없으면(initState 직후 등) 서버가 마지막으로 보낸 값을
  /// 그대로 폴백한다.
  /// ★dispose 경로에서는 이 함수가 실제 위치를 잴 수 없다.★ Element 트리는
  /// 자식부터 unmount되므로 [dispose]가 도는 시점에는 `Scrollable`이 이미
  /// 정리돼 `hasClients == false`다. 그때 서버가 마지막으로 준 값을 폴백으로
  /// 돌려주면, 그 값이 [ContentProgressTracker.record]를 거치며 tracker에
  /// 쌓여 있던 **최신 진행률을 덮어쓴다**(정기 flush 임계가 0.1이라 최대 10%가
  /// 매번 유실되고, 완료 임계 0.8 근처에서는 완료 처리가 지연된다).
  /// 그래서 마지막으로 **실측에 성공한** 값을 [_lastObservedScrollPct]에 남겨
  /// 폴백보다 먼저 쓴다.
  double _scrollPct(double fallback) {
    if (!_scrollController.hasClients) {
      return _lastObservedScrollPct ?? fallback;
    }
    final position = _scrollController.position;
    final headerHeight = _headerHeight;
    if (headerHeight == null) return _lastObservedScrollPct ?? fallback;
    final maxExtent = position.maxScrollExtent - headerHeight;
    if (maxExtent <= 0) return 1;
    final pixels = position.pixels - headerHeight;
    final pct = (pixels / maxExtent).clamp(0, 1).toDouble();
    _lastObservedScrollPct = pct;
    return pct;
  }

  double? get _headerHeight {
    final box = _headerKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    return box.size.height;
  }

  Future<void> _postProgress(ContentProgressFlush flush) async {
    final pageEpoch = _pageEpoch;
    final workspaceKey = widget.workspaceKey;
    final missionController = workspaceKey == null
        ? null
        : _missionController(workspaceKey);
    _posting = true;
    try {
      final response = missionController != null
          ? await missionController.reportProgress(
              scrollPct: flush.scrollPct,
              dwellSec: flush.dwellSec,
            )
          : await _contentController!.reportProgress(
              idOrSlug: widget.contentId,
              scrollPct: flush.scrollPct,
              dwellSec: flush.dwellSec,
            );
      if (pageEpoch != _pageEpoch || !mounted) return;
      if (response == null) {
        _failedFlush = _failedFlush?.merge(flush) ?? flush;
        return;
      }
      _failedFlush = null;
      if (!response.completed || !mounted) return;
      _tracker?.markCompleted();
      if (missionController != null) return;
      await ref.read(pathControllerProvider.notifier).loadOrStart();
      await ref.read(dashboardControllerProvider.notifier).load();
    } finally {
      if (pageEpoch == _pageEpoch) _posting = false;
    }
  }

  void _retryFailedProgress() {
    final flush = _failedFlush;
    if (flush != null) {
      unawaited(_postProgress(flush));
      return;
    }
    final workspaceKey = widget.workspaceKey;
    if (workspaceKey != null) {
      unawaited(_missionController(workspaceKey).retryProgress());
      return;
    }
    _maybeFlushProgress(force: true);
  }

  void _flushCachedProgressOnDispose() {
    final workspaceKey = widget.workspaceKey;
    if (_posting && workspaceKey == null) return;
    final content =
        _latestContent ??
        switch (_latestLegacyState) {
          ContentLoaded(:final content) => content,
          _ => null,
        };
    if (content == null) return;
    _syncTracker(content);
    final tracker = _tracker;
    if (tracker == null) return;

    final scrollPct = _scrollPct(content.progress.scrollPct);
    final recorded = tracker.record(scrollPct: scrollPct, dwellSec: _dwellSec);
    var flush = recorded ?? tracker.disposeFlush();
    final failedFlush = _failedFlush;
    if (failedFlush != null) {
      flush = flush?.merge(failedFlush) ?? failedFlush;
    }
    if (flush == null) return;
    final flushToSend = flush;
    if (workspaceKey != null) {
      final missionController = _lastMissionContentController;
      if (missionController == null) return;
      // Provider listeners are still being detached while dispose runs.
      // Defer the retained controller mutation until tree finalization ends.
      scheduleMicrotask(() {
        unawaited(
          missionController.reportProgress(
            scrollPct: flushToSend.scrollPct,
            dwellSec: flushToSend.dwellSec,
          ),
        );
      });
      return;
    }
    unawaited(
      _apiClient
          .post<Map<String, dynamic>>(
            '/contents/${widget.contentId}/progress',
            body: {
              'scrollPct': flushToSend.scrollPct,
              'dwellSec': flushToSend.dwellSec,
            },
          )
          .catchError((_) => <String, dynamic>{}),
    );
  }
}

class _MissionContentHeader extends StatelessWidget {
  const _MissionContentHeader({
    required this.workspaceKey,
    required this.mission,
    required this.content,
  });

  final MissionWorkspaceKey workspaceKey;
  final CurrentMission? mission;
  final LearningContent? content;

  @override
  Widget build(BuildContext context) {
    final matchingTasks = mission?.tasks
        .where((candidate) => candidate.taskId == workspaceKey.taskId)
        .toList();
    final task = matchingTasks?.length == 1 ? matchingTasks!.single : null;
    final progress =
        content?.progress.scrollPct ?? (task?.completed == true ? 1 : 0);
    final completed = content?.progress.completed ?? task?.completed ?? false;
    final weekNum = mission?.weekNum;
    return DpMissionHeader(
      eyebrow: weekNum == null ? '오늘의 미션' : '$weekNum주차 · 오늘의 미션',
      title: task?.title ?? content?.title ?? '현재 학습 미션',
      why: weekNum == null
          ? '맞춤 경로의 현재 학습 맥락을 이어갑니다.'
          : '맞춤 경로 $weekNum주차의 현재 학습 맥락을 이어갑니다.',
      completionCriterion: '콘텐츠 학습 진행률을 충족해 완료 상태를 저장합니다',
      progressValue: progress.clamp(0, 1).toDouble(),
      progressLabel: '콘텐츠 학습 진행률',
      status: completed
          ? DpMissionHeaderStatus.completed
          : DpMissionHeaderStatus.active,
    );
  }
}

class _InlineContentError extends StatelessWidget {
  const _InlineContentError({
    required this.message,
    required this.actionLabel,
    required this.onRetry,
  });

  final String message;
  final String actionLabel;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.dpColors;
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceMuted,
          border: Border.all(color: colors.danger),
          borderRadius: BorderRadius.circular(context.appTokens.panelRadius),
        ),
        child: Padding(
          padding: const EdgeInsets.all(DpSpacing.md),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final action = TextButton(
                onPressed: onRetry,
                child: Text(actionLabel),
              );
              if (constraints.maxWidth < 520) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(message),
                    const SizedBox(height: DpSpacing.xs),
                    Align(alignment: Alignment.centerLeft, child: action),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: Text(message)),
                  const SizedBox(width: DpSpacing.sm),
                  action,
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Loaded content production projection shared by the live page and the ET13
/// browser-distribution fixture.
class WebContentProjection extends StatelessWidget {
  const WebContentProjection({
    super.key,
    required this.content,
    this.adSlot = const AdSlotWidget(slot: 'CONTENT_PAGE'),
  });

  final LearningContent content;
  final Widget adSlot;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = context.dpColors;
    final progress = content.progress;
    final percent = (progress.scrollPct * 100).round().clamp(0, 100);
    final meta = [
      if (content.estimatedMinutes != null) '${content.estimatedMinutes}분',
      if (content.bloomLevel != null) content.bloomLevel!,
      if (content.difficulty != null) '난이도 ${content.difficulty}',
    ];

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 840),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(content.title, style: text.headlineSmall),
            const SizedBox(height: DpSpacing.sm),
            if (meta.isNotEmpty)
              Text(
                meta.join(' · '),
                style: text.bodySmall?.copyWith(color: colors.textSecondary),
              ),
            const SizedBox(height: DpSpacing.md),
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: progress.scrollPct.clamp(0, 1).toDouble(),
                  ),
                ),
                const SizedBox(width: DpSpacing.sm),
                Text(
                  progress.completed ? '완료' : '$percent% 진행',
                  style: text.labelMedium,
                ),
              ],
            ),
            if (content.conceptTags.isNotEmpty) ...[
              const SizedBox(height: DpSpacing.md),
              Wrap(
                spacing: DpSpacing.xs,
                runSpacing: DpSpacing.xs,
                children: [
                  for (final tag in content.conceptTags) Chip(label: Text(tag)),
                ],
              ),
            ],
            const SizedBox(height: DpSpacing.xl),
            DpMarkdown(data: content.markdown),
            const SizedBox(height: DpSpacing.lg),
            adSlot,
          ],
        ),
      ),
    );
  }
}
