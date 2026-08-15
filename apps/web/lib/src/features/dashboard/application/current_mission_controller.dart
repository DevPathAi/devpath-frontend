import 'dart:async';

import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/api_providers.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/state/auth_state.dart';

typedef CurrentMissionClock = DateTime Function();

final currentMissionClockProvider = Provider<CurrentMissionClock>(
  (ref) => DateTime.now,
);

/// 캐시를 인증 계정에 묶는다. logout/account switch 시 이전 사용자의 retained
/// mission이 30초 cache window 안에서 새 사용자에게 보이면 안 된다.
final currentMissionOwnerKeyProvider = Provider<String?>((ref) {
  return ref.watch(
    authControllerProvider.select(
      (auth) => switch (auth) {
        AuthAuthenticated(:final user) => user.id,
        _ => null,
      },
    ),
  );
});

enum CurrentMissionFailureKind { initialLoad, refresh, completion }

const _notProvided = Object();

/// Today가 마지막으로 확인한 미션을 요청·mutation 실패와 분리해 보존한다.
final class CurrentMissionState {
  const CurrentMissionState({
    this.mission,
    this.isLoading = false,
    this.isStale = false,
    this.failureKind,
    this.failureMessage,
    this.completingTaskId,
    this.generation = 0,
  });

  final CurrentMission? mission;
  final bool isLoading;
  final bool isStale;
  final CurrentMissionFailureKind? failureKind;
  final String? failureMessage;
  final int? completingTaskId;
  final int generation;

  bool get hasUsableMission => mission != null;
  bool get isInitialLoading => isLoading && mission == null;

  CurrentMissionState copyWith({
    Object? mission = _notProvided,
    bool? isLoading,
    bool? isStale,
    Object? failureKind = _notProvided,
    Object? failureMessage = _notProvided,
    Object? completingTaskId = _notProvided,
    int? generation,
  }) => CurrentMissionState(
    mission: identical(mission, _notProvided)
        ? this.mission
        : mission as CurrentMission?,
    isLoading: isLoading ?? this.isLoading,
    isStale: isStale ?? this.isStale,
    failureKind: identical(failureKind, _notProvided)
        ? this.failureKind
        : failureKind as CurrentMissionFailureKind?,
    failureMessage: identical(failureMessage, _notProvided)
        ? this.failureMessage
        : failureMessage as String?,
    completingTaskId: identical(completingTaskId, _notProvided)
        ? this.completingTaskId
        : completingTaskId as int?,
    generation: generation ?? this.generation,
  );
}

/// Authoritative Today projection의 web-owned cache/mutation coordinator.
///
/// 하나의 세대 안에서는 모든 consumer가 같은 in-flight 요청을 공유한다. 명시적
/// invalidate는 세대를 올리고 현재 in-flight 참조를 떼어내므로 새 조회를 즉시
/// 시작할 수 있으며, 취소할 수 없는 이전 응답은 generation 비교로 버린다.
class CurrentMissionController extends Notifier<CurrentMissionState> {
  static const freshnessWindow = Duration(seconds: 30);

  DateTime? _cachedAt;
  Future<CurrentMission?>? _inFlight;
  int? _inFlightGeneration;
  Future<CurrentMission?>? _completionInFlight;
  int? _completionTaskId;
  var _generation = 0;
  var _disposed = false;
  String? _ownerKey;

  @override
  CurrentMissionState build() {
    _ownerKey = ref.read(currentMissionOwnerKeyProvider);
    ref.listen(currentMissionOwnerKeyProvider, (_, ownerKey) {
      if (_disposed || ownerKey == _ownerKey) return;
      _ownerKey = ownerKey;
      _generation += 1;
      _cachedAt = null;
      _inFlight = null;
      _inFlightGeneration = null;
      _completionInFlight = null;
      _completionTaskId = null;
      state = CurrentMissionState(isLoading: true, generation: _generation);
      // 같은 Dashboard가 살아 있는 account switch에서도 loading 상태에
      // 멈추지 않는다. 로그아웃(null)은 인증 요청을 새로 만들지 않는다.
      if (ownerKey != null) unawaited(load(force: true));
    });
    ref.onDispose(() {
      _disposed = true;
      _generation += 1;
      _inFlight = null;
      _completionInFlight = null;
    });
    return CurrentMissionState(isLoading: true, generation: _generation);
  }

  Future<CurrentMission?> load({bool force = false}) {
    final active = _inFlight;
    if (active != null && _inFlightGeneration == _generation) return active;

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
    tracked =
        _fetch(
          generation,
          hadData
              ? CurrentMissionFailureKind.refresh
              : CurrentMissionFailureKind.initialLoad,
        ).whenComplete(() {
          if (identical(_inFlight, tracked)) {
            _inFlight = null;
            _inFlightGeneration = null;
          }
        });
    _inFlight = tracked;
    _inFlightGeneration = generation;
    return tracked;
  }

  /// 캐시를 stale로 표시하고 이전 세대 응답이 state를 덮지 못하게 한다.
  void invalidate() {
    _generation += 1;
    _cachedAt = null;
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
    if (mission?.outcome != CurrentMissionOutcome.available ||
        task?.taskId != taskId ||
        task?.contentId != null) {
      return Future.error(StateError('현재 contentless 미션만 명시적으로 완료할 수 있습니다.'));
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
    final cachedAt = _cachedAt;
    if (cachedAt == null || state.mission == null) return false;
    final age = ref.read(currentMissionClockProvider)().difference(cachedAt);
    return age < freshnessWindow;
  }

  Future<CurrentMission?> _fetch(
    int generation,
    CurrentMissionFailureKind failureKind,
  ) async {
    try {
      final mission = await ref.read(learningPathApiProvider).currentMission();
      if (_disposed || generation != _generation) return null;
      _cachedAt = ref.read(currentMissionClockProvider)();
      state = state.copyWith(
        mission: mission,
        isLoading: false,
        isStale: false,
        failureKind: null,
        failureMessage: null,
        generation: generation,
      );
      return mission;
    } on Object catch (error) {
      if (_disposed || generation != _generation) return null;
      state = state.copyWith(
        isLoading: false,
        isStale: state.mission != null,
        failureKind: failureKind,
        failureMessage: _failureMessage(error),
        generation: generation,
      );
      return state.mission;
    }
  }

  Future<CurrentMission?> _complete(int taskId, int generation) async {
    try {
      await ref.read(learningPathApiProvider).completeContentlessTask(taskId);
      if (_disposed || generation != _generation) return null;

      // 성공한 write만 cache를 무효화한다. 서버가 확인한 다음 task를 즉시
      // 다시 읽으며, refetch 실패 시에는 이전 incomplete 미션을 stale로 남긴다.
      _generation += 1;
      _cachedAt = null;
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
      if (_disposed || generation != _generation) return null;
      state = state.copyWith(
        completingTaskId: null,
        failureKind: CurrentMissionFailureKind.completion,
        failureMessage: _failureMessage(error),
      );
      return state.mission;
    }
  }

  String _failureMessage(Object error) => switch (error) {
    ApiException(:final message) => message,
    _ => '현재 미션을 새로 확인하지 못했어요.',
  };
}

final currentMissionControllerProvider =
    NotifierProvider<CurrentMissionController, CurrentMissionState>(
      CurrentMissionController.new,
    );
