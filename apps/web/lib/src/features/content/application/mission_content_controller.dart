import 'dart:async';
import 'dart:math' as math;

import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/api_providers.dart';
import '../../dashboard/application/current_mission_controller.dart';
import '../../mission/state/mission_workspace_key.dart';

const _notProvided = Object();

/// Canonical mission content keeps usable data separate from load/progress errors.
final class MissionContentState {
  const MissionContentState({
    this.content,
    this.isLoading = false,
    this.progressSubmitting = false,
    this.failureMessage,
    this.progressFailureMessage,
    this.ownerKey,
    this.generation = 0,
  });

  final LearningContent? content;
  final bool isLoading;
  final bool progressSubmitting;
  final String? failureMessage;
  final String? progressFailureMessage;
  final String? ownerKey;
  final int generation;

  MissionContentState copyWith({
    Object? content = _notProvided,
    bool? isLoading,
    bool? progressSubmitting,
    Object? failureMessage = _notProvided,
    Object? progressFailureMessage = _notProvided,
    Object? ownerKey = _notProvided,
    int? generation,
  }) => MissionContentState(
    content: identical(content, _notProvided)
        ? this.content
        : content as LearningContent?,
    isLoading: isLoading ?? this.isLoading,
    progressSubmitting: progressSubmitting ?? this.progressSubmitting,
    failureMessage: identical(failureMessage, _notProvided)
        ? this.failureMessage
        : failureMessage as String?,
    progressFailureMessage: identical(progressFailureMessage, _notProvided)
        ? this.progressFailureMessage
        : progressFailureMessage as String?,
    ownerKey: identical(ownerKey, _notProvided)
        ? this.ownerKey
        : ownerKey as String?,
    generation: generation ?? this.generation,
  );
}

class MissionContentController extends Notifier<MissionContentState> {
  MissionContentController(this.workspaceKey);

  final MissionWorkspaceKey workspaceKey;
  var _ownerEpoch = 0;
  var _loadEpoch = 0;
  var _disposed = false;
  String? _ownerKey;
  Future<LearningContent?>? _loadInFlight;
  Future<ContentProgressUpdateResponse?>? _progressInFlight;
  double? _activeScrollPct;
  int? _activeDwellSec;
  double? _pendingScrollPct;
  int? _pendingDwellSec;
  bool _completionNotified = false;

  @override
  MissionContentState build() {
    _ownerKey = ref.read(currentMissionOwnerKeyProvider);
    ref.listen(currentMissionOwnerKeyProvider, (_, nextOwner) {
      if (_disposed || nextOwner == _ownerKey) return;
      _ownerKey = nextOwner;
      _ownerEpoch += 1;
      _loadEpoch += 1;
      _loadInFlight = null;
      _progressInFlight = null;
      _activeScrollPct = null;
      _activeDwellSec = null;
      _pendingScrollPct = null;
      _pendingDwellSec = null;
      _completionNotified = false;
      state = MissionContentState(
        // A canonical route must be revalidated against the new owner's Today
        // projection before it is allowed to issue another content GET.
        isLoading: false,
        ownerKey: nextOwner,
        generation: _ownerEpoch,
      );
    });
    ref.onDispose(() {
      _disposed = true;
      _ownerEpoch += 1;
      _loadEpoch += 1;
      _loadInFlight = null;
      _progressInFlight = null;
      _pendingScrollPct = null;
      _pendingDwellSec = null;
    });
    return MissionContentState(ownerKey: _ownerKey, generation: _ownerEpoch);
  }

  bool isBoundTo(String? ownerKey) => !_disposed && _ownerKey == ownerKey;

  bool get hasPendingProgress =>
      _pendingScrollPct != null && _pendingDwellSec != null;

  /// Stops an inactive retained family before Riverpod removes its element.
  /// Late HTTP responses are generation-guarded and later owner changes no
  /// longer trigger background loads through this instance.
  void retire() {
    if (_disposed) return;
    _disposed = true;
    _ownerEpoch += 1;
    _loadEpoch += 1;
    _loadInFlight = null;
    _progressInFlight = null;
    _pendingScrollPct = null;
    _pendingDwellSec = null;
  }

  Future<LearningContent?> load({bool force = false}) {
    final active = _loadInFlight;
    if (!force && active != null) return active;
    if (!force && state.content != null && state.failureMessage == null) {
      return Future.value(state.content);
    }
    if (_ownerKey == null) return Future.value(null);

    if (force) {
      _loadEpoch += 1;
      _loadInFlight = null;
    }
    final loadEpoch = _loadEpoch;
    final ownerEpoch = _ownerEpoch;
    final ownerKey = _ownerKey;
    state = state.copyWith(
      isLoading: true,
      failureMessage: null,
      generation: ownerEpoch,
      ownerKey: ownerKey,
    );

    late final Future<LearningContent?> tracked;
    tracked = _load(loadEpoch, ownerEpoch, ownerKey).whenComplete(() {
      if (identical(_loadInFlight, tracked)) _loadInFlight = null;
    });
    _loadInFlight = tracked;
    return tracked;
  }

  Future<ContentProgressUpdateResponse?> reportProgress({
    required double scrollPct,
    required int dwellSec,
  }) {
    if (_disposed) return Future.value(null);
    final normalizedScroll = scrollPct.clamp(0, 1).toDouble();
    final normalizedDwell = math.max(0, dwellSec);
    final active = _progressInFlight;
    if (active != null) {
      final activeCovers =
          (_activeScrollPct ?? 0) >= normalizedScroll &&
          (_activeDwellSec ?? 0) >= normalizedDwell;
      if (!activeCovers) {
        _pendingScrollPct = math.max(
          math.max(_pendingScrollPct ?? 0, _activeScrollPct ?? 0),
          normalizedScroll,
        );
        _pendingDwellSec = math.max(
          math.max(_pendingDwellSec ?? 0, _activeDwellSec ?? 0),
          normalizedDwell,
        );
      }
      return active;
    }
    final content = state.content;
    final ownerKey = _ownerKey;
    if (content == null || ownerKey == null) return Future.value(null);

    _pendingScrollPct = math.max(_pendingScrollPct ?? 0, normalizedScroll);
    _pendingDwellSec = math.max(_pendingDwellSec ?? 0, normalizedDwell);
    return _startProgressDrain(ownerKey);
  }

  /// Retries the monotonic progress payload retained after a failed write.
  /// This belongs to the keyed controller rather than the page so navigating
  /// away while a request fails cannot discard a queued dispose flush.
  Future<ContentProgressUpdateResponse?> retryProgress() {
    if (_disposed) return Future.value(null);
    final active = _progressInFlight;
    if (active != null) return active;
    final ownerKey = _ownerKey;
    if (state.content == null ||
        ownerKey == null ||
        _pendingScrollPct == null ||
        _pendingDwellSec == null) {
      return Future.value(null);
    }
    return _startProgressDrain(ownerKey);
  }

  Future<ContentProgressUpdateResponse?> _startProgressDrain(String ownerKey) {
    final ownerEpoch = _ownerEpoch;
    state = state.copyWith(
      progressSubmitting: true,
      progressFailureMessage: null,
    );

    late final Future<ContentProgressUpdateResponse?> tracked;
    tracked = _drainProgress(ownerEpoch, ownerKey).whenComplete(() {
      if (identical(_progressInFlight, tracked)) {
        _progressInFlight = null;
        _activeScrollPct = null;
        _activeDwellSec = null;
        if (!_disposed && !hasPendingProgress) {
          ref
              .read(missionContentRetentionProvider.notifier)
              .release(workspaceKey);
        }
      }
    });
    _progressInFlight = tracked;
    return tracked;
  }

  Future<LearningContent?> _load(
    int loadEpoch,
    int ownerEpoch,
    String? ownerKey,
  ) async {
    try {
      final json = await ref
          .read(apiClientProvider)
          .get<Map<String, dynamic>>('/contents/${workspaceKey.contentId}');
      final content = LearningContent.fromJson(json);
      if (content.id != workspaceKey.contentId) {
        throw const FormatException('content identity mismatch');
      }
      if (!_isCurrentLoad(loadEpoch, ownerEpoch, ownerKey)) return null;
      state = state.copyWith(
        content: content,
        isLoading: false,
        failureMessage: null,
        progressFailureMessage: null,
      );
      return content;
    } on Object catch (error) {
      if (!_isCurrentLoad(loadEpoch, ownerEpoch, ownerKey)) return null;
      state = state.copyWith(
        isLoading: false,
        failureMessage: _loadFailureMessage(error),
      );
      return state.content;
    }
  }

  Future<ContentProgressUpdateResponse?> _drainProgress(
    int ownerEpoch,
    String ownerKey,
  ) async {
    ContentProgressUpdateResponse? lastResponse;
    while (_isCurrentOwner(ownerEpoch, ownerKey)) {
      final scrollPct = _pendingScrollPct;
      final dwellSec = _pendingDwellSec;
      if (scrollPct == null || dwellSec == null) break;
      _pendingScrollPct = null;
      _pendingDwellSec = null;
      _activeScrollPct = scrollPct;
      _activeDwellSec = dwellSec;
      final response = await _sendProgress(
        ownerEpoch,
        ownerKey,
        scrollPct: scrollPct,
        dwellSec: dwellSec,
      );
      if (response == null) return null;
      lastResponse = response;
    }
    if (_isCurrentOwner(ownerEpoch, ownerKey)) {
      state = state.copyWith(progressSubmitting: false);
    }
    return lastResponse;
  }

  Future<ContentProgressUpdateResponse?> _sendProgress(
    int ownerEpoch,
    String ownerKey, {
    required double scrollPct,
    required int dwellSec,
  }) async {
    final completedBeforeWrite = state.content?.progress.completed ?? false;
    try {
      final json = await ref
          .read(apiClientProvider)
          .post<Map<String, dynamic>>(
            '/contents/${workspaceKey.contentId}/progress',
            body: {'scrollPct': scrollPct, 'dwellSec': dwellSec},
          );
      final response = ContentProgressUpdateResponse.fromJson(json);
      if (!_isCurrentOwner(ownerEpoch, ownerKey)) return null;

      final currentContent = state.content;
      if (currentContent == null) return null;
      final completedNow =
          !completedBeforeWrite && response.completed && !_completionNotified;
      state = state.copyWith(
        content: currentContent.copyWith(
          progress: _mergeProgress(currentContent.progress, response),
        ),
        progressFailureMessage: null,
      );
      if (completedNow) {
        _completionNotified = true;
        unawaited(
          ref
              .read(currentMissionControllerProvider.notifier)
              .invalidateAndRefetch(),
        );
      }
      return response;
    } on Object catch (error) {
      if (_isCurrentOwner(ownerEpoch, ownerKey)) {
        _pendingScrollPct = math.max(_pendingScrollPct ?? 0, scrollPct);
        _pendingDwellSec = math.max(_pendingDwellSec ?? 0, dwellSec);
        state = state.copyWith(
          progressSubmitting: false,
          progressFailureMessage: _progressFailureMessage(error),
        );
      }
      return null;
    }
  }

  bool _isCurrentOwner(int ownerEpoch, String? ownerKey) =>
      !_disposed && ownerEpoch == _ownerEpoch && ownerKey == _ownerKey;

  bool _isCurrentLoad(int loadEpoch, int ownerEpoch, String? ownerKey) =>
      _isCurrentOwner(ownerEpoch, ownerKey) && loadEpoch == _loadEpoch;

  ContentProgress _mergeProgress(
    ContentProgress current,
    ContentProgressUpdateResponse response,
  ) => ContentProgress(
    scrollPct: math.max(current.scrollPct, response.scrollPct),
    dwellSec: math.max(current.dwellSec, response.dwellSec),
    completed: current.completed || response.completed,
    completedAt: response.completedAt ?? current.completedAt,
  );

  String _loadFailureMessage(Object error) => switch (error) {
    FormatException() => '미션과 콘텐츠 연결을 확인하지 못했어요.',
    ApiException(:final message) => message,
    _ => '콘텐츠 형식을 확인하지 못했어요.',
  };

  String _progressFailureMessage(Object error) => switch (error) {
    ApiException(:final message) => message,
    _ => '진행률을 저장하지 못했어요.',
  };
}

final missionContentControllerProvider =
    NotifierProvider.family<
      MissionContentController,
      MissionContentState,
      MissionWorkspaceKey
    >(MissionContentController.new);

/// Keeps only the two most recently used canonical workspaces. Account changes
/// clear the retention index. Each keyed controller owns the synchronous
/// account reset so an active route cannot race an external invalidation.
class MissionContentRetentionController
    extends Notifier<List<MissionWorkspaceKey>> {
  String? _ownerKey;
  final _pendingEvictions = <MissionWorkspaceKey>{};
  final _activeKeys = <MissionWorkspaceKey>{};

  @override
  List<MissionWorkspaceKey> build() {
    _ownerKey = ref.read(currentMissionOwnerKeyProvider);
    ref.listen(currentMissionOwnerKeyProvider, (_, nextOwner) {
      if (nextOwner == _ownerKey) return;
      _ownerKey = nextOwner;
      final trackedKeys = <MissionWorkspaceKey>{...state, ..._pendingEvictions};
      state = List.unmodifiable(trackedKeys.where(_activeKeys.contains));
      _pendingEvictions.clear();
      // Owner-scoped controllers hide the previous account's data before this
      // listener runs. Retire and invalidate every retained family now so none
      // survive to observe another account or issue background GETs.
      for (final key in trackedKeys) {
        if (_activeKeys.contains(key)) continue;
        ref.read(missionContentControllerProvider(key).notifier).retire();
        ref.invalidate(missionContentControllerProvider(key));
      }
    });
    return const [];
  }

  void touch(MissionWorkspaceKey key) {
    _pendingEvictions.remove(key);
    final next = [...state.where((candidate) => candidate != key), key];
    if (next.length > 2) {
      final evicted = next.removeAt(0);
      _evictOrDefer(evicted);
    }
    state = List.unmodifiable(next);
  }

  void activate(MissionWorkspaceKey key) {
    _activeKeys.add(key);
    touch(key);
  }

  void deactivate(MissionWorkspaceKey key) {
    _activeKeys.remove(key);
  }

  void release(MissionWorkspaceKey key) {
    if (!_pendingEvictions.remove(key)) return;
    scheduleMicrotask(() {
      ref.invalidate(missionContentControllerProvider(key));
    });
  }

  void clear() {
    final previous = state;
    state = const [];
    for (final key in previous) {
      _evictOrDefer(key);
    }
  }

  void _evictOrDefer(MissionWorkspaceKey key) {
    final controller = ref.read(missionContentControllerProvider(key).notifier);
    final contentState = ref.read(missionContentControllerProvider(key));
    if (contentState.progressSubmitting || controller.hasPendingProgress) {
      _pendingEvictions.add(key);
      return;
    }
    ref.invalidate(missionContentControllerProvider(key));
  }
}

final missionContentRetentionProvider =
    NotifierProvider<
      MissionContentRetentionController,
      List<MissionWorkspaceKey>
    >(MissionContentRetentionController.new);
