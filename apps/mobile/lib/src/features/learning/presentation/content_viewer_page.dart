import 'dart:async';

import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/api_providers.dart';
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
  late final ContentController _contentController;
  late final ApiClient _apiClient;
  Timer? _dwellTimer;
  ContentProgressTracker? _tracker;
  String? _trackedSlug;
  ContentState? _latestState;
  int _dwellSec = 0;
  bool _posting = false;

  @override
  void initState() {
    super.initState();
    // dispose 시 ref 사용이 불가하므로 의존성을 미리 캐싱(web content_page와 동일 패턴).
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
      (_) => _contentController.load(widget.slug),
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
    _flushOnDispose();
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
          onRetry: () => _contentController.load(widget.slug),
        ),
        ContentLoaded(:final content) => _ContentBody(
          slug: widget.slug,
          content: content,
          controller: _scrollController,
        ),
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
    // 콘텐츠가 화면보다 짧아 스크롤이 없으면 다 본 것으로 간주(1.0).
    if (position.maxScrollExtent <= 0) return 1;
    return (position.pixels / position.maxScrollExtent).clamp(0, 1).toDouble();
  }

  Future<void> _postProgress(ContentProgressFlush flush) async {
    _posting = true;
    try {
      final resp = await _contentController.reportProgress(
        widget.slug,
        scrollPct: flush.scrollPct,
        dwellSec: flush.dwellSec,
      );
      if (resp?.completed == true) _tracker?.markCompleted();
    } finally {
      _posting = false;
    }
  }

  /// 페이지 이탈 시 잔여 진척을 캐싱된 [_apiClient]로 직접 보고한다(ref 미사용 — dispose 안전).
  void _flushOnDispose() {
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
            '/contents/${widget.slug}/progress',
            body: {'scrollPct': flush.scrollPct, 'dwellSec': flush.dwellSec},
          )
          .catchError((_) => <String, dynamic>{}),
    );
  }
}

class _ContentBody extends ConsumerWidget {
  const _ContentBody({
    required this.slug,
    required this.content,
    required this.controller,
  });

  final String slug;
  final LearningContent content;
  final ScrollController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = content.progress;
    final completed = progress.completed;
    final percent = (progress.scrollPct * 100).round().clamp(0, 100);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: progress.scrollPct.clamp(0, 1).toDouble(),
                ),
              ),
              const SizedBox(width: 8),
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
            padding: const EdgeInsets.all(16),
            child: DpMarkdown(data: content.markdown),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: completed
                    ? null
                    : () => ref
                          .read(contentControllerProvider.notifier)
                          .markComplete(slug),
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
