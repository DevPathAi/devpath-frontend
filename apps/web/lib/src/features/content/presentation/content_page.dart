import 'dart:async';

import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/content_controller.dart';
import '../application/content_progress_tracker.dart';
import '../state/content_state.dart';
import '../../dashboard/application/dashboard_controller.dart';
import '../../path/application/path_controller.dart';
import '../../../providers/api_providers.dart';

class ContentPage extends ConsumerStatefulWidget {
  const ContentPage({super.key, required this.contentId});
  final String contentId;

  @override
  ConsumerState<ContentPage> createState() => _ContentPageState();
}

class _ContentPageState extends ConsumerState<ContentPage>
    with WidgetsBindingObserver {
  final _scrollController = ScrollController();
  late final ContentController _contentController;
  late final ApiClient _apiClient;
  Timer? _dwellTimer;
  ContentProgressTracker? _tracker;
  String? _trackedContentKey;
  ContentState? _latestState;
  int _dwellSec = 0;
  bool _posting = false;

  @override
  void initState() {
    super.initState();
    _contentController = ref.read(contentControllerProvider.notifier);
    _apiClient = ref.read(apiClientProvider);
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_maybeFlushProgress);
    _dwellTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final state = ref.read(contentControllerProvider);
      if (state is! ContentLoaded || state.content.progress.completed) return;
      _dwellSec++;
      _maybeFlushProgress();
    });
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _contentController.load(widget.contentId),
    );
  }

  @override
  void didUpdateWidget(covariant ContentPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.contentId == widget.contentId) return;
    _resetProgressTracker();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _contentController.load(widget.contentId),
    );
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
    _dwellTimer?.cancel();
    _scrollController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(contentControllerProvider);
    _latestState = s;
    ref.listen<ContentState>(contentControllerProvider, (_, next) {
      _latestState = next;
      if (next case ContentLoaded(:final content)) {
        _syncTracker(content);
      }
    });
    return Scaffold(
      appBar: AppBar(
        title: const Text('학습 콘텐츠'),
        actions: [
          TextButton.icon(
            onPressed: () => context.go('/sandbox'),
            icon: const Icon(DpIcons.code),
            label: const Text('실습'),
          ),
        ],
      ),
      body: switch (s) {
        ContentLoading() => const DpLoading(),
        ContentFailed(:final message) => DpError(
          message: message,
          onRetry: () => _contentController.load(widget.contentId),
        ),
        ContentLoaded(:final content) => _ContentBody(
          controller: _scrollController,
          content: content,
        ),
      },
    );
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
    _dwellSec = 0;
    _posting = false;
  }

  void _maybeFlushProgress({bool force = false}) {
    if (_posting) return;
    final state = ref.read(contentControllerProvider);
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
    if (position.maxScrollExtent <= 0) return 1;
    return (position.pixels / position.maxScrollExtent).clamp(0, 1).toDouble();
  }

  Future<void> _postProgress(ContentProgressFlush flush) async {
    _posting = true;
    try {
      final response = await ref
          .read(contentControllerProvider.notifier)
          .reportProgress(
            idOrSlug: widget.contentId,
            scrollPct: flush.scrollPct,
            dwellSec: flush.dwellSec,
          );
      if (response?.completed != true || !mounted) return;
      _tracker?.markCompleted();
      await ref.read(pathControllerProvider.notifier).loadOrStart();
      await ref.read(dashboardControllerProvider.notifier).load();
    } finally {
      _posting = false;
    }
  }

  void _flushCachedProgressOnDispose() {
    if (_posting) return;
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
      _apiClient
          .post<Map<String, dynamic>>(
            '/contents/${widget.contentId}/progress',
            body: {'scrollPct': flush.scrollPct, 'dwellSec': flush.dwellSec},
          )
          .catchError((_) => <String, dynamic>{}),
    );
  }
}

class _ContentBody extends StatelessWidget {
  const _ContentBody({required this.controller, required this.content});

  final ScrollController controller;
  final LearningContent content;

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

    return SingleChildScrollView(
      controller: controller,
      padding: const EdgeInsets.all(DpSpacing.lg),
      child: Center(
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
                    for (final tag in content.conceptTags)
                      Chip(label: Text(tag)),
                  ],
                ),
              ],
              const SizedBox(height: DpSpacing.xl),
              DpMarkdown(data: content.markdown),
            ],
          ),
        ),
      ),
    );
  }
}
