import 'dart:async';

import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../application/content_controller.dart';
import '../application/content_progress_tracker.dart';
import '../state/content_state.dart';

/// 모바일 학습 뷰어 — 콘텐츠 마크다운 렌더 + 진척 자동추적(스크롤·체류) + 수동 완료.
///
/// 스크롤/체류를 [ContentProgressTracker]로 추적해 임계마다 서버에 보고하고,
/// 완료 임계(스크롤 80% + 체류 45초) 도달 시 자동 완료한다. 페이지 이탈 시 잔여 진척을 flush.
class ContentViewerPage extends ConsumerStatefulWidget {
  const ContentViewerPage({super.key, required this.slug});

  final String slug;

  @override
  ConsumerState<ContentViewerPage> createState() => _ContentViewerPageState();
}

class _ContentViewerPageState extends ConsumerState<ContentViewerPage>
    with WidgetsBindingObserver {
  final _scrollController = ScrollController();
  ContentController? _activeController;
  Timer? _dwellTimer;
  ContentProgressTracker? _tracker;
  String? _trackedSlug;
  ContentState? _latestState;
  int _dwellSec = 0;
  int? _postingGeneration;
  var _boundaryGeneration = 0;
  int? _loadStartedGeneration;
  String? _ownerKey;

  @override
  void initState() {
    super.initState();
    _ownerKey = ref.read(currentOwnerKeyProvider);
    ref.listenManual(currentOwnerKeyProvider, (previous, next) {
      if (_ownerKey == next) return;
      _ownerKey = next;
      _resetBoundary();
    });
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_maybeFlushProgress);
    _dwellTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final state = ref.read(contentControllerProvider(widget.slug));
      if (state is! ContentLoaded || state.content.progress.completed) return;
      _dwellSec++;
      _maybeFlushProgress();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduleLoad();
    });
  }

  @override
  void didUpdateWidget(covariant ContentViewerPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.slug == widget.slug) return;
    _resetBoundary();
    _scheduleLoad();
  }

  void _resetBoundary() {
    _boundaryGeneration += 1;
    _activeController = null;
    _tracker = null;
    _trackedSlug = null;
    _latestState = null;
    _dwellSec = 0;
  }

  void _scheduleLoad() {
    final slug = widget.slug;
    final generation = _boundaryGeneration;
    if (_loadStartedGeneration == generation) return;
    _loadStartedGeneration = generation;
    scheduleMicrotask(() {
      if (!mounted ||
          slug != widget.slug ||
          generation != _boundaryGeneration) {
        return;
      }
      unawaited(ref.read(contentControllerProvider(slug).notifier).load());
    });
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
    _flushOnDispose();
    _dwellTimer?.cancel();
    _scrollController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = contentControllerProvider(widget.slug);
    final controller = ref.read(provider.notifier);
    _activeController = controller;
    final s = ref.watch(provider);
    _latestState = s;
    ref.listen<ContentState>(provider, (_, next) {
      _latestState = next;
      if (next case ContentLoaded(:final content)) _syncTracker(content);
    });
    return Scaffold(
      appBar: AppBar(
        title: Text(switch (s) {
          ContentLoaded(:final content) => content.title,
          _ => '학습',
        }),
      ),
      body: switch (s) {
        ContentLoading() => const DpLoading(),
        ContentFailed(:final message) => DpError(
          message: message,
          onRetry: controller.load,
        ),
        ContentLoaded(:final content)
            when content.slug == widget.slug ||
                content.id.toString() == widget.slug =>
          _ContentBody(
            slug: widget.slug,
            content: content,
            controller: _scrollController,
            progressFailureMessage: s.progressFailureMessage,
            loadFailureMessage: s.loadFailureMessage,
            fromOfflineCache: s.fromOfflineCache,
            onComplete: controller.markComplete,
          ),
        ContentLoaded() => const DpLoading(),
      },
    );
  }

  void _syncTracker(LearningContent content) {
    final key = content.slug.isNotEmpty ? content.slug : content.id.toString();
    if (_trackedSlug == key) {
      if (content.progress.completed) _tracker?.markCompleted();
      return;
    }
    _trackedSlug = key;
    _dwellSec = content.progress.dwellSec;
    _tracker = ContentProgressTracker(
      initialScrollPct: content.progress.scrollPct,
      initialDwellSec: content.progress.dwellSec,
      completed: content.progress.completed,
    );
  }

  void _maybeFlushProgress({bool force = false}) {
    if (_postingGeneration == _boundaryGeneration) return;
    final state = ref.read(contentControllerProvider(widget.slug));
    _latestState = state;
    if (state is! ContentLoaded) return;
    _syncTracker(state.content);
    final tracker = _tracker;
    if (tracker == null) return;

    final scrollPct = _scrollPct(state.content.progress.scrollPct);
    final recorded = tracker.record(scrollPct: scrollPct, dwellSec: _dwellSec);
    final flush = force ? recorded ?? tracker.disposeFlush() : recorded;
    if (flush != null) unawaited(_postProgress(flush));
  }

  double _scrollPct(double fallback) {
    if (!_scrollController.hasClients) return fallback;
    final position = _scrollController.position;
    // 콘텐츠가 화면보다 짧아 스크롤이 없으면 다 본 것으로 간주(1.0).
    if (position.maxScrollExtent <= 0) return 1;
    return (position.pixels / position.maxScrollExtent).clamp(0, 1).toDouble();
  }

  Future<void> _postProgress(ContentProgressFlush flush) async {
    final controller = _activeController;
    if (controller == null) return;
    final slug = widget.slug;
    final boundaryGeneration = _boundaryGeneration;
    _postingGeneration = boundaryGeneration;
    try {
      final resp = await controller.reportProgress(
        slug,
        scrollPct: flush.scrollPct,
        dwellSec: flush.dwellSec,
      );
      if (boundaryGeneration == _boundaryGeneration &&
          resp?.completed == true) {
        _tracker?.markCompleted();
      }
    } finally {
      if (_postingGeneration == boundaryGeneration) {
        _postingGeneration = null;
      }
    }
  }

  /// 페이지 이탈 시에도 같은 controller 경계로 보내 완료 무효화와 단조 병합을 유지한다.
  void _flushOnDispose() {
    if (_postingGeneration == _boundaryGeneration) return;
    final controller = _activeController;
    if (controller == null) return;
    final slug = widget.slug;
    final state = _latestState;
    if (state is! ContentLoaded) return;
    _syncTracker(state.content);
    final tracker = _tracker;
    if (tracker == null) return;

    final scrollPct = _scrollPct(state.content.progress.scrollPct);
    final recorded = tracker.record(scrollPct: scrollPct, dwellSec: _dwellSec);
    final flush = recorded ?? tracker.disposeFlush();
    if (flush == null) return;
    unawaited(
      Future<void>.microtask(() async {
        await controller.reportProgress(
          slug,
          scrollPct: flush.scrollPct,
          dwellSec: flush.dwellSec,
        );
      }),
    );
  }
}

class _ContentBody extends ConsumerWidget {
  const _ContentBody({
    required this.slug,
    required this.content,
    required this.controller,
    this.progressFailureMessage,
    this.loadFailureMessage,
    this.fromOfflineCache = false,
    required this.onComplete,
  });

  final String slug;
  final LearningContent content;
  final ScrollController controller;
  final String? progressFailureMessage;
  final String? loadFailureMessage;
  final bool fromOfflineCache;
  final Future<void> Function([String?]) onComplete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = content.progress;
    final completed = progress.completed;
    final percent = (progress.scrollPct * 100).round().clamp(0, 100);
    final meta = [
      if (content.estimatedMinutes != null) '${content.estimatedMinutes}분',
      if (content.bloomLevel != null)
        DpLearningLabels.bloomLevel(content.bloomLevel!),
      if (content.difficulty != null)
        '난이도 ${DpLearningLabels.difficulty(content.difficulty!)}',
    ];
    return Column(
      children: [
        if (loadFailureMessage != null)
          DpOfflineBanner(
            message: fromOfflineCache
                ? '오프라인에 저장된 콘텐츠예요. $loadFailureMessage'
                : '읽던 콘텐츠를 유지했어요. $loadFailureMessage',
          ),
        if (progressFailureMessage != null)
          DpOfflineBanner(
            message: '$progressFailureMessage 읽던 콘텐츠와 로컬 진행률은 유지했어요.',
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            DpSpacing.lg,
            DpSpacing.sm,
            DpSpacing.lg,
            0,
          ),
          child: Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: progress.scrollPct.clamp(0, 1).toDouble(),
                ),
              ),
              const SizedBox(width: DpSpacing.sm),
              Text(
                completed ? '완료' : '$percent%',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            controller: controller,
            padding: const EdgeInsets.all(DpSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (meta.isNotEmpty)
                  Text(
                    meta.join(' · '),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.dpColors.textSecondary,
                    ),
                  ),
                if (content.conceptTags.isNotEmpty) ...[
                  const SizedBox(height: DpSpacing.sm),
                  Wrap(
                    spacing: DpSpacing.sm,
                    runSpacing: DpSpacing.sm,
                    children: [
                      for (final t in content.conceptTags)
                        Chip(label: Text('#$t')),
                    ],
                  ),
                ],
                if (meta.isNotEmpty || content.conceptTags.isNotEmpty)
                  const SizedBox(height: DpSpacing.lg),
                DpContextCapsule(
                  name: '이 콘텐츠의 학습 맥락',
                  mode: DpContextCapsuleMode.collapsed,
                  fields: [
                    DpContextFieldViewModel(
                      id: 'track',
                      label: '학습 경로',
                      valueSummary: DpLearningLabels.track(content.track),
                      source: '현재 콘텐츠',
                      sensitivity: DpContextSensitivity.low,
                      inclusion: DpContextInclusion.included,
                    ),
                    if (content.bloomLevel != null)
                      DpContextFieldViewModel(
                        id: 'bloom',
                        label: '학습 단계',
                        valueSummary: DpLearningLabels.bloomLevel(
                          content.bloomLevel!,
                        ),
                        source: '현재 콘텐츠',
                        sensitivity: DpContextSensitivity.low,
                        inclusion: DpContextInclusion.included,
                      ),
                  ],
                ),
                const SizedBox(height: DpSpacing.lg),
                DpMarkdown(data: content.markdown),
              ],
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(DpSpacing.lg),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: completed ? null : () => onComplete(),
                icon: const Icon(DpIcons.stepDone),
                label: Text(completed ? '완료됨' : '완료로 표시'),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
