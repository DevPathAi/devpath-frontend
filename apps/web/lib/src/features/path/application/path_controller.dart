import 'dart:async';
import 'dart:convert';

import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/api_providers.dart';
import '../data/path_sse_source.dart';

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

  @override
  PathState build() {
    ref.onDispose(() => _sub?.cancel());
    return const PathState();
  }

  /// 기존 ACTIVE 경로가 있으면 바로 보여주고, 없을 때만 새 경로를 생성한다.
  Future<void> loadOrStart() async {
    try {
      await _loadResult();
      return;
    } on ApiException catch (e) {
      if (e.status != 404) {
        state = state.copyWith(phase: PathPhase.failed, error: e.message);
        return;
      }
    }
    await start();
  }

  /// 처음부터 생성.
  Future<void> start() {
    _sub?.cancel();
    final done = Completer<void>();

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
        final pathEvent = _eventOf(event.data);
        if (pathEvent == null) return;
        if (pathEvent.stage == 'error') {
          await _sub?.cancel();
          state = state.copyWith(
            phase: PathPhase.failed,
            error: pathEvent.message,
          );
          if (!done.isCompleted) done.complete();
          return;
        }
        if (pathEvent.stage == 'done') {
          await _sub?.cancel(); // onDone 경합 방지
          try {
            await _loadResult();
          } on ApiException catch (e) {
            state = state.copyWith(phase: PathPhase.failed, error: e.message);
          }
          if (!done.isCompleted) done.complete();
          return;
        }
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
        // ENG-REVIEW F4: 503(KILL_SWITCH)/429(Quota)는 partial이 아니라 종료 분기로
        // 끝내 재시도 루프를 막는다. 그 외 네트워크 끊김만 partial로 처리한다.
        if (e is ApiException && (e.isKillSwitch || e.isQuota)) {
          state = state.copyWith(
            phase: e.isKillSwitch ? PathPhase.killSwitch : PathPhase.failed,
            error: e.message,
          );
        } else {
          state = state.copyWith(
            phase: PathPhase.partial,
            error: 'SSE 연결이 끊겼어요',
          );
        }
        if (!done.isCompleted) done.complete();
      },
      onDone: () {
        // DONE 없이 정상 종료 = 중단으로 간주.
        if (state.phase == PathPhase.streaming) {
          state = state.copyWith(phase: PathPhase.partial, error: '생성이 중단됐어요');
        }
        if (!done.isCompleted) done.complete();
      },
      cancelOnError: true,
    );

    return done.future;
  }

  Future<void> _loadResult() async {
    final json = await ref
        .read(apiClientProvider)
        .get<Map<String, dynamic>>('/learning-paths/me');
    state = state.copyWith(
      phase: PathPhase.complete,
      completed: kPathStageLabels,
      result: LearningPath.fromJson(json),
    );
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
