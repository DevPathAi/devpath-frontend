import 'dart:async';
import 'dart:convert';

import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/api_providers.dart';
import '../data/path_sse_source.dart';

const _unexpectedPathLoadError = '학습 경로를 불러오지 못했어요. 다시 시도해 주세요.';

/// PATH 생성 phase. ENG-REVIEW D1: P2 `SseStage`(connecting/streaming/partial/
/// reconnecting/complete/failed)가 **단일 출처**다. 이 enum은 그것을 재정의한 게
/// 아니라 feature 관점으로 **매핑**한 것. [killSwitch]는 §9.2의 503/429를 partial과
/// 구분하기 위한 전용 phase(F4).
enum PathPhase { idle, streaming, partial, complete, failed, killSwitch }

/// PATH 생성 상태. [completed]=완료 단계 라벨(중단 시 보존), [current]=진행 라벨.
class PathState {
  const PathState({
    this.phase = PathPhase.idle,
    this.completed = const [],
    this.current,
    this.result,
    this.error,
  });

  final PathPhase phase;
  final List<String> completed;
  final String? current;
  final LearningPath? result;
  final String? error;

  PathState copyWith({
    PathPhase? phase,
    List<String>? completed,
    String? current,
    LearningPath? result,
    String? error,
  }) => PathState(
    phase: phase ?? this.phase,
    completed: completed ?? this.completed,
    current: current,
    result: result ?? this.result,
    error: error,
  );
}

class PathController extends Notifier<PathState> {
  StreamSubscription<SseEvent>? _sub;
  Completer<void>? _streamDone;
  int _generation = 0;

  @override
  PathState build() {
    ref.onDispose(_invalidateActiveOperation);
    return const PathState();
  }

  /// Path data is user-scoped. The router calls this on logout or an identity
  /// change so a completed path from the previous user cannot be rendered.
  void reset() {
    _invalidateActiveOperation();
    state = const PathState();
  }

  /// 기존 ACTIVE 경로가 있으면 바로 보여주고, 없을 때만 새 경로를 생성한다.
  Future<void> loadOrStart() async {
    final generation = _beginOperation();
    try {
      await _loadResult(generation);
      return;
    } on ApiException catch (e) {
      if (!_isCurrent(generation)) return;
      if (e.status != 404) {
        state = state.copyWith(phase: PathPhase.failed, error: e.message);
        return;
      }
    } catch (error) {
      if (!_isCurrent(generation)) return;
      _finishLoadFailure(error, generation);
      return;
    }
    if (!_isCurrent(generation)) return;
    await start();
  }

  /// 처음부터 생성.
  Future<void> start() {
    final generation = _beginOperation();
    final done = Completer<void>();
    _streamDone = done;

    state = PathState(
      phase: PathPhase.streaming,
      completed: const [],
      current: kPathStageLabels.first,
    );

    // ENG-REVIEW D2: 60s 무이벤트 → partial 전환. config.sseTimeout 초과 시 timeout이
    // 스트림에 ApiException(network)를 주입하고, killSwitch/quota가 아니므로 partial로 처리된다.
    final stream = ref
        .read(pathSseConnectProvider)()
        .timeout(
          ref.read(appConfigProvider).sseTimeout,
          onTimeout: (sink) => sink.addError(
            const ApiException(code: ApiErrorCode.network, message: '생성이 지연돼요'),
          ),
        );

    _sub = stream.listen(
      (event) async {
        if (!_isCurrent(generation)) return;
        final pathEvent = _eventOf(event.data);
        if (pathEvent == null) return;
        // 중간 에러는 백엔드가 event:error 프레임으로 보내며 SseClient가 ApiException으로
        // throw한다(C2) → onError에서 처리. 인밴드 progress(stage=error)는 더 이상 없다.
        if (pathEvent.stage == 'done') {
          final subscription = _sub;
          _sub = null;
          if (subscription != null) unawaited(subscription.cancel());
          try {
            await _loadResult(generation);
          } catch (error) {
            _finishLoadFailure(error, generation);
          }
          _completeStream(generation, done);
          return;
        }
        if (!_isCurrent(generation)) return;
        final idx = kPathStages.indexOf(pathEvent.stage);
        if (idx < 0 || idx >= kPathStageLabels.length) return;
        state = state.copyWith(
          phase: PathPhase.streaming,
          completed: kPathStageLabels.take(idx + 1).toList(),
          current: idx + 1 < kPathStageLabels.length
              ? kPathStageLabels[idx + 1]
              : null,
        );
      },
      onError: (Object e) {
        if (!_isCurrent(generation)) {
          _completeStream(generation, done);
          return;
        }
        // ENG-REVIEW F4: 503(KILL_SWITCH)/429(Quota)는 partial이 아니라 종료 분기로
        // 끝내 재시도 루프를 막는다. 그 외 네트워크 끊김만 partial로 처리한다.
        if (e is ApiException && (e.isKillSwitch || e.isQuota)) {
          state = state.copyWith(
            phase: e.isKillSwitch ? PathPhase.killSwitch : PathPhase.failed,
            error: e.message,
          );
        } else if (e is ApiException && e.code != ApiErrorCode.network) {
          // 중간 event:error = 서버 확정 실패(네트워크 끊김과 구분).
          state = state.copyWith(phase: PathPhase.failed, error: e.message);
        } else if (state.phase == PathPhase.streaming) {
          state = state.copyWith(phase: PathPhase.partial, error: '생성이 중단됐어요');
        }
        _completeStream(generation, done);
      },
      onDone: () {
        if (!_isCurrent(generation)) {
          _completeStream(generation, done);
          return;
        }
        // DONE 없이 정상 종료 = 중단으로 간주.
        if (state.phase == PathPhase.streaming) {
          state = state.copyWith(phase: PathPhase.partial, error: '생성이 중단됐어요');
        }
        _completeStream(generation, done);
      },
      cancelOnError: true,
    );

    return done.future;
  }

  Future<void> _loadResult(int generation) async {
    final result = await ref.read(learningPathApiProvider).currentPath();
    if (!_isCurrent(generation)) return;
    state = state.copyWith(
      phase: PathPhase.complete,
      completed: kPathStageLabels,
      result: result,
    );
  }

  void _finishLoadFailure(Object error, int generation) {
    if (!_isCurrent(generation)) return;
    state = state.copyWith(
      phase: PathPhase.failed,
      error: error is ApiException ? error.message : _unexpectedPathLoadError,
    );
  }

  int _beginOperation() {
    _invalidateActiveOperation();
    return _generation;
  }

  bool _isCurrent(int generation) => generation == _generation;

  void _invalidateActiveOperation() {
    _generation++;
    final subscription = _sub;
    _sub = null;
    if (subscription != null) unawaited(subscription.cancel());
    final done = _streamDone;
    _streamDone = null;
    if (done != null && !done.isCompleted) done.complete();
  }

  void _completeStream(int generation, Completer<void> done) {
    if (_isCurrent(generation) && identical(_streamDone, done)) {
      _streamDone = null;
    }
    if (!done.isCompleted) done.complete();
  }

  PathSseEvent? _eventOf(String data) {
    try {
      final m = jsonDecode(data);
      if (m is! Map<String, dynamic>) return null;
      return PathSseEvent.fromJson(m);
    } catch (_) {
      return null;
    }
  }
}

final pathControllerProvider = NotifierProvider<PathController, PathState>(
  PathController.new,
);
