import 'dart:async';

import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/api_providers.dart';
import '../../auth/application/auth_controller.dart';
import '../data/current_mission_cache.dart';

typedef TodayClock = DateTime Function();

final todayClockProvider = Provider<TodayClock>((ref) => DateTime.now);

final todayOwnerKeyProvider = Provider<String?>((ref) {
  return ref.watch(currentOwnerKeyProvider);
});

enum TodayMissionSource { online, offlineCache }

enum TodayFailureKind { initialLoad, refresh, completion }

const _notProvided = Object();

final class TodayState {
  const TodayState({
    this.mission,
    this.isLoading = false,
    this.isStale = false,
    this.source = TodayMissionSource.online,
    this.cachedAt,
    this.failureKind,
    this.failureMessage,
    this.completingTaskId,
    this.generation = 0,
  });

  final CurrentMission? mission;
  final bool isLoading;
  final bool isStale;
  final TodayMissionSource source;
  final DateTime? cachedAt;
  final TodayFailureKind? failureKind;
  final String? failureMessage;
  final int? completingTaskId;
  final int generation;

  bool get isInitialLoading => isLoading && mission == null;
  bool get isOffline => source == TodayMissionSource.offlineCache;

  TodayState copyWith({
    Object? mission = _notProvided,
    bool? isLoading,
    bool? isStale,
    TodayMissionSource? source,
    Object? cachedAt = _notProvided,
    Object? failureKind = _notProvided,
    Object? failureMessage = _notProvided,
    Object? completingTaskId = _notProvided,
    int? generation,
  }) => TodayState(
    mission: identical(mission, _notProvided)
        ? this.mission
        : mission as CurrentMission?,
    isLoading: isLoading ?? this.isLoading,
    isStale: isStale ?? this.isStale,
    source: source ?? this.source,
    cachedAt: identical(cachedAt, _notProvided)
        ? this.cachedAt
        : cachedAt as DateTime?,
    failureKind: identical(failureKind, _notProvided)
        ? this.failureKind
        : failureKind as TodayFailureKind?,
    failureMessage: identical(failureMessage, _notProvided)
        ? this.failureMessage
        : failureMessage as String?,
    completingTaskId: identical(completingTaskId, _notProvided)
        ? this.completingTaskId
        : completingTaskId as int?,
    generation: generation ?? this.generation,
  );
}

/// Mobile owner for authoritative Today, its 30-second shared online snapshot,
/// and the separately labelled 24-hour offline snapshot.
class TodayController extends Notifier<TodayState> {
  static const freshnessWindow = Duration(seconds: 30);

  DateTime? _onlineCachedAt;
  Future<CurrentMission?>? _inFlight;
  int? _inFlightGeneration;
  Future<CurrentMission?>? _completionInFlight;
  int? _completionTaskId;
  var _generation = 0;
  var _disposed = false;
  String? _ownerKey;

  @override
  TodayState build() {
    _ownerKey = ref.read(todayOwnerKeyProvider);
    ref.listen(todayOwnerKeyProvider, (_, ownerKey) {
      if (_disposed || ownerKey == _ownerKey) return;
      _ownerKey = ownerKey;
      _generation += 1;
      _onlineCachedAt = null;
      _inFlight = null;
      _inFlightGeneration = null;
      _completionInFlight = null;
      _completionTaskId = null;
      state = TodayState(isLoading: ownerKey != null, generation: _generation);
      if (ownerKey != null) unawaited(load(force: true));
    });
    ref.onDispose(() {
      _disposed = true;
      _generation += 1;
      _inFlight = null;
      _completionInFlight = null;
    });
    return TodayState(isLoading: _ownerKey != null, generation: _generation);
  }

  Future<CurrentMission?> load({bool force = false}) {
    final active = _inFlight;
    if (active != null && _inFlightGeneration == _generation) return active;
    if (_ownerKey == null) return Future.value(null);
    if (!force && _isFresh()) return Future.value(state.mission);

    final generation = _generation;
    final hadData = state.mission != null;
    state = state.copyWith(
      isLoading: true,
      isStale: hadData,
      failureKind: null,
      failureMessage: null,
      generation: generation,
    );

    late final Future<CurrentMission?> tracked;
    tracked = _fetch(generation, hadData).whenComplete(() {
      if (identical(_inFlight, tracked)) {
        _inFlight = null;
        _inFlightGeneration = null;
      }
    });
    _inFlight = tracked;
    _inFlightGeneration = generation;
    return tracked;
  }

  void invalidate() {
    _generation += 1;
    _onlineCachedAt = null;
    _inFlight = null;
    _inFlightGeneration = null;
    _completionInFlight = null;
    _completionTaskId = null;
    if (_disposed) return;
    state = state.copyWith(
      isLoading: false,
      isStale: state.mission != null,
      failureKind: null,
      failureMessage: null,
      completingTaskId: null,
      generation: _generation,
    );
  }

  Future<CurrentMission?> invalidateAndRefetch() {
    invalidate();
    return load(force: true);
  }

  Future<CurrentMission?> completeContentlessTask(int taskId) {
    final active = _completionInFlight;
    if (active != null) {
      if (_completionTaskId == taskId) return active;
      return Future.error(StateError('다른 미션 완료 요청이 처리 중입니다.'));
    }

    final mission = state.mission;
    final task = mission?.nextTask;
    if (state.isOffline ||
        state.isStale ||
        mission?.outcome != CurrentMissionOutcome.available ||
        task?.taskId != taskId ||
        task?.contentId != null) {
      return Future.error(StateError('온라인의 현재 contentless 미션만 완료할 수 있습니다.'));
    }

    final generation = _generation;
    state = state.copyWith(
      completingTaskId: taskId,
      failureKind: null,
      failureMessage: null,
    );
    late final Future<CurrentMission?> tracked;
    tracked = _complete(taskId, generation).whenComplete(() {
      if (identical(_completionInFlight, tracked)) {
        _completionInFlight = null;
        _completionTaskId = null;
      }
    });
    _completionInFlight = tracked;
    _completionTaskId = taskId;
    return tracked;
  }

  bool _isFresh() {
    final cachedAt = _onlineCachedAt;
    if (cachedAt == null || state.mission == null || state.isOffline) {
      return false;
    }
    final age = ref.read(todayClockProvider)().difference(cachedAt);
    return !age.isNegative && age < freshnessWindow;
  }

  Future<CurrentMission?> _fetch(int generation, bool hadData) async {
    final ownerKey = _ownerKey;
    if (ownerKey == null) return null;
    final missionCache = ref.read(currentMissionCacheProvider);
    try {
      final mission = await ref.read(learningPathApiProvider).currentMission();
      if (!_isCurrent(generation, ownerKey)) return null;
      final now = ref.read(todayClockProvider)();
      if (mission.outcome != CurrentMissionOutcome.malformedPath) {
        try {
          await missionCache.write(ownerKey, mission, cachedAt: now);
        } on Object {
          // Online Today remains usable when the local persistence layer fails.
        }
      }
      if (!_isCurrent(generation, ownerKey)) {
        try {
          await missionCache.clearIfMatches(ownerKey, mission, cachedAt: now);
        } on Object {
          // Account cleanup remains best-effort when local storage is broken.
        }
        return null;
      }
      _onlineCachedAt = now;
      state = state.copyWith(
        mission: mission,
        isLoading: false,
        isStale: false,
        source: TodayMissionSource.online,
        cachedAt: now,
        failureKind: null,
        failureMessage: null,
        generation: generation,
      );
      return mission;
    } on Object catch (error) {
      if (!_isCurrent(generation, ownerKey)) return null;
      CachedCurrentMission? cached;
      if (!hadData) {
        try {
          cached = await ref
              .read(currentMissionCacheProvider)
              .read(ownerKey, now: ref.read(todayClockProvider)());
        } on Object {
          cached = null;
        }
      }
      if (!_isCurrent(generation, ownerKey)) return null;
      if (cached != null) {
        state = state.copyWith(
          mission: cached.mission,
          isLoading: false,
          isStale: true,
          source: TodayMissionSource.offlineCache,
          cachedAt: cached.cachedAt,
          failureKind: TodayFailureKind.initialLoad,
          failureMessage: _failureMessage(error),
          generation: generation,
        );
        return cached.mission;
      }
      state = state.copyWith(
        isLoading: false,
        isStale: state.mission != null,
        failureKind: hadData
            ? TodayFailureKind.refresh
            : TodayFailureKind.initialLoad,
        failureMessage: _failureMessage(error),
        generation: generation,
      );
      return state.mission;
    }
  }

  Future<CurrentMission?> _complete(int taskId, int generation) async {
    final ownerKey = _ownerKey;
    try {
      await ref.read(learningPathApiProvider).completeContentlessTask(taskId);
      if (ownerKey == null || !_isCurrent(generation, ownerKey)) return null;
      _generation += 1;
      _onlineCachedAt = null;
      _inFlight = null;
      _inFlightGeneration = null;
      state = state.copyWith(
        completingTaskId: null,
        isStale: true,
        failureKind: null,
        failureMessage: null,
        generation: _generation,
      );
      return load(force: true);
    } on Object catch (error) {
      if (ownerKey == null || !_isCurrent(generation, ownerKey)) return null;
      state = state.copyWith(
        completingTaskId: null,
        failureKind: TodayFailureKind.completion,
        failureMessage: _failureMessage(error),
      );
      return state.mission;
    }
  }

  bool _isCurrent(int generation, String ownerKey) =>
      !_disposed && generation == _generation && ownerKey == _ownerKey;

  String _failureMessage(Object error) => switch (error) {
    ApiException(:final message) => message,
    _ => '현재 미션을 새로 확인하지 못했어요.',
  };
}

final todayControllerProvider = NotifierProvider<TodayController, TodayState>(
  TodayController.new,
);
