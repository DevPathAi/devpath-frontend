import 'dart:async';
import 'dart:math' as math;

import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/api_providers.dart';
import '../../auth/application/auth_controller.dart';
import '../../today/application/today_controller.dart';
import '../data/content_offline_store.dart';
import '../state/content_state.dart';
import 'content_progress_sync_controller.dart';

/// One independent state machine per canonical content route key.
class ContentController extends Notifier<ContentState> {
  ContentController(this.routeKey);

  final String routeKey;
  var _loadGeneration = 0;
  String? _ownerKey;

  @override
  ContentState build() {
    _ownerKey = ref.read(currentOwnerKeyProvider);
    ref.listen(currentOwnerKeyProvider, (_, owner) {
      if (owner == _ownerKey) return;
      _ownerKey = owner;
      _loadGeneration += 1;
      state = const ContentLoading();
      if (owner != null) Future<void>.microtask(load);
    });
    if (_ownerKey != null) {
      ref.listen(contentProgressSyncControllerProvider, (previous, next) {
        if (previous != next) unawaited(_refreshFromOfflineStore());
      });
    }
    return const ContentLoading();
  }

  Future<void> _refreshFromOfflineStore() async {
    final owner = _ownerKey;
    final generation = _loadGeneration;
    final before = state;
    if (owner == null || before is! ContentLoaded) return;
    final cached = await ref
        .read(contentOfflineStoreProvider)
        .read(owner, routeKey, now: DateTime.now().toUtc());
    if (!_isCurrent(owner, generation) || cached == null) return;
    final latest = state;
    if (latest is! ContentLoaded || !_matches(latest.content)) return;
    state = ContentLoaded(
      cached.content,
      loadFailureMessage: latest.loadFailureMessage,
      isStale: latest.isStale,
      fromOfflineCache: latest.fromOfflineCache,
      cachedAt: latest.cachedAt,
    );
  }

  Future<void> load([String? requestedRoute]) async {
    if (requestedRoute != null && requestedRoute != routeKey) {
      state = const ContentFailed('콘텐츠 경로가 일치하지 않아요.');
      return;
    }
    final generation = ++_loadGeneration;
    final owner = _ownerKey;
    final retained = state is ContentLoaded ? state as ContentLoaded : null;
    if (retained == null) {
      state = const ContentLoading();
    } else {
      state = ContentLoaded(
        retained.content,
        progressFailureMessage: retained.progressFailureMessage,
        isRefreshing: true,
        isStale: retained.isStale,
        fromOfflineCache: retained.fromOfflineCache,
        cachedAt: retained.cachedAt,
      );
    }
    try {
      final json = await ref
          .read(apiClientProvider)
          .get<Map<String, dynamic>>('/contents/$routeKey');
      var content = LearningContent.fromJson(json);
      if (!_matches(content)) {
        throw const FormatException('content identity mismatch');
      }
      if (!_isCurrent(owner, generation)) return;
      final now = DateTime.now().toUtc();
      if (owner != null) {
        content = await _mergeQueuedProgress(owner, content);
        if (!_isCurrent(owner, generation)) return;
        try {
          await ref
              .read(contentOfflineStoreProvider)
              .write(owner, routeKey, content, cachedAt: now);
        } on Object {
          // Local persistence cannot make authoritative content unusable.
        }
      }
      if (!_isCurrent(owner, generation)) return;
      state = ContentLoaded(content, cachedAt: now);
    } on Object catch (error) {
      if (!_isCurrent(owner, generation)) return;
      final message = _loadFailure(error);
      if (retained != null) {
        state = ContentLoaded(
          retained.content,
          progressFailureMessage: retained.progressFailureMessage,
          loadFailureMessage: message,
          isStale: true,
          fromOfflineCache: retained.fromOfflineCache,
          cachedAt: retained.cachedAt,
        );
        return;
      }
      CachedLearningContent? cached;
      if (owner != null) {
        try {
          cached = await ref
              .read(contentOfflineStoreProvider)
              .read(owner, routeKey, now: DateTime.now().toUtc());
        } on Object {
          cached = null;
        }
      }
      if (!_isCurrent(owner, generation)) return;
      final restored = cached == null || owner == null
          ? cached?.content
          : await _mergeQueuedProgress(owner, cached.content);
      if (!_isCurrent(owner, generation)) return;
      state = restored == null
          ? ContentFailed(message)
          : ContentLoaded(
              restored,
              loadFailureMessage: message,
              isStale: true,
              fromOfflineCache: true,
              cachedAt: cached?.cachedAt,
            );
    }
  }

  Future<void> markComplete([String? requestedRoute]) async {
    if (requestedRoute != null && requestedRoute != routeKey) return;
    await _reportProgress(scrollPct: 1, dwellSec: 60, requestCompletion: true);
  }

  Future<ContentProgressUpdateResponse?> reportProgress(
    String requestedRoute, {
    required double scrollPct,
    required int dwellSec,
  }) {
    if (requestedRoute != routeKey) return Future.value(null);
    return _reportProgress(
      scrollPct: scrollPct,
      dwellSec: dwellSec,
      requestCompletion: false,
    );
  }

  Future<ContentProgressUpdateResponse?> _reportProgress({
    required double scrollPct,
    required int dwellSec,
    required bool requestCompletion,
  }) async {
    final before = state;
    if (before is! ContentLoaded || !_matches(before.content)) return null;
    final owner = _ownerKey;
    final generation = _loadGeneration;
    final localProgress = before.content.progress;
    state = ContentLoaded(
      before.content.copyWith(
        progress: ContentProgress(
          scrollPct: math.max(localProgress.scrollPct, scrollPct),
          dwellSec: math.max(localProgress.dwellSec, dwellSec),
          completed: localProgress.completed,
          completedAt: localProgress.completedAt,
        ),
      ),
      loadFailureMessage: before.loadFailureMessage,
      isStale: before.isStale,
      fromOfflineCache: before.fromOfflineCache,
      cachedAt: before.cachedAt,
    );

    ContentProgressUpdateResponse? response;
    if (owner == null) {
      response = await _postDirect(scrollPct: scrollPct, dwellSec: dwellSec);
    } else {
      response = await ref
          .read(contentProgressSyncControllerProvider.notifier)
          .enqueueAndSync(
            QueuedContentProgress(
              ownerKey: owner,
              routeKey: routeKey,
              scrollPct: scrollPct.clamp(0, 1).toDouble(),
              dwellSec: math.max(0, dwellSec),
              requestCompletion: requestCompletion,
            ),
          );
    }
    if (!_isCurrent(owner, generation)) return response;
    if (response == null) {
      final latest = state;
      if (latest is ContentLoaded && _matches(latest.content)) {
        state = ContentLoaded(
          latest.content,
          progressFailureMessage: '진행률을 동기화하지 못했어요.',
          loadFailureMessage: latest.loadFailureMessage,
          isStale: latest.isStale,
          fromOfflineCache: latest.fromOfflineCache,
          cachedAt: latest.cachedAt,
        );
      }
      return null;
    }
    _applyServerProgress(response, invalidateToday: owner == null);
    return response;
  }

  Future<ContentProgressUpdateResponse?> _postDirect({
    required double scrollPct,
    required int dwellSec,
  }) async {
    try {
      final json = await ref
          .read(apiClientProvider)
          .post<Map<String, dynamic>>(
            '/contents/$routeKey/progress',
            body: {'scrollPct': scrollPct, 'dwellSec': dwellSec},
          );
      return ContentProgressUpdateResponse.fromJson(json);
    } on Object {
      return null;
    }
  }

  void _applyServerProgress(
    ContentProgressUpdateResponse response, {
    required bool invalidateToday,
  }) {
    final latest = state;
    if (latest is! ContentLoaded || !_matches(latest.content)) return;
    final previous = latest.content.progress;
    final completedNow = !previous.completed && response.completed;
    state = ContentLoaded(
      latest.content.copyWith(
        progress: ContentProgress(
          scrollPct: math.max(previous.scrollPct, response.scrollPct),
          dwellSec: math.max(previous.dwellSec, response.dwellSec),
          completed: previous.completed || response.completed,
          completedAt: response.completedAt ?? previous.completedAt,
        ),
      ),
      loadFailureMessage: latest.loadFailureMessage,
      isStale: latest.isStale,
      fromOfflineCache: latest.fromOfflineCache,
      cachedAt: latest.cachedAt,
    );
    if (invalidateToday &&
        completedNow &&
        ref.exists(todayControllerProvider)) {
      unawaited(
        ref.read(todayControllerProvider.notifier).invalidateAndRefetch(),
      );
    }
  }

  bool _matches(LearningContent content) =>
      content.slug == routeKey || content.id.toString() == routeKey;

  bool _isCurrent(String? owner, int generation) =>
      ref.mounted && owner == _ownerKey && generation == _loadGeneration;

  Future<LearningContent> _mergeQueuedProgress(
    String ownerKey,
    LearningContent content,
  ) async {
    final pending = await ref
        .read(contentProgressQueueProvider)
        .read(ownerKey, routeKey);
    if (pending == null) return content;
    final progress = content.progress;
    return content.copyWith(
      progress: ContentProgress(
        scrollPct: math.max(progress.scrollPct, pending.scrollPct),
        dwellSec: math.max(progress.dwellSec, pending.dwellSec),
        completed: progress.completed,
        completedAt: progress.completedAt,
      ),
    );
  }

  String _loadFailure(Object error) => switch (error) {
    ApiException(:final message) => message,
    FormatException() => '미션과 콘텐츠 연결을 확인하지 못했어요.',
    _ => '콘텐츠 형식을 확인하지 못했어요.',
  };
}

final contentControllerProvider =
    NotifierProvider.family<ContentController, ContentState, String>(
      ContentController.new,
    );
