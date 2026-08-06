import 'dart:async';

import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/content_controller.dart';
import '../application/content_progress_tracker.dart';
import '../state/content_state.dart';
import '../../ads/presentation/ad_slot_widget.dart';
import '../../dashboard/application/dashboard_controller.dart';
import '../../path/application/path_controller.dart';
import '../../../providers/api_providers.dart';
import '../../support/presentation/supportable_error.dart';

class ContentPage extends ConsumerStatefulWidget {
  const ContentPage({super.key, required this.contentId});
  final String contentId;

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
    final c = context.dpColors;
    return Scaffold(
      body: CustomScrollView(
        // 진행률 추적(_scrollPct)이 이 컨트롤러 하나로 헤더+본문 전체 스크롤
        // 범위를 관측한다 — 본문에 별도 스크롤 위젯을 두면 중첩 스크롤이 되어
        // 헤더가 스크롤과 함께 사라지지 않는다.
        controller: _scrollController,
        slivers: [
          SliverToBoxAdapter(
            child: DpPageHeader(
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
            ),
          ),
          switch (s) {
            ContentLoading() => const SliverFillRemaining(
              hasScrollBody: false,
              child: DpLoading(),
            ),
            ContentFailed(:final message) => SliverFillRemaining(
              hasScrollBody: false,
              child: SupportableError(
                message: message,
                onRetry: () => _contentController.load(widget.contentId),
              ),
            ),
            ContentLoaded(:final content) => SliverPadding(
              padding: const EdgeInsets.all(DpSpacing.lg),
              sliver: SliverToBoxAdapter(child: _ContentBody(content: content)),
            ),
          },
        ],
      ),
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
  double _scrollPct(double fallback) {
    if (!_scrollController.hasClients) return fallback;
    final position = _scrollController.position;
    final headerHeight = _headerHeight;
    if (headerHeight == null) return fallback;
    final maxExtent = position.maxScrollExtent - headerHeight;
    if (maxExtent <= 0) return 1;
    final pixels = position.pixels - headerHeight;
    return (pixels / maxExtent).clamp(0, 1).toDouble();
  }

  double? get _headerHeight {
    final box = _headerKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    return box.size.height;
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
  const _ContentBody({required this.content});

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
            const AdSlotWidget(slot: 'CONTENT_PAGE'),
          ],
        ),
      ),
    );
  }
}
