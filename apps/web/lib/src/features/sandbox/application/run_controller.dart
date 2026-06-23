import 'dart:async';

import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/sandbox_run_source.dart';
import '../state/run_state.dart';

class RunController extends Notifier<RunState> {
  StreamSubscription<SseEvent>? _sub;
  int? _sessionId; // F6-e: session SSE 이벤트로 수신한 sandboxSessionId

  @override
  RunState build() {
    ref.onDispose(() => _sub?.cancel());
    return const RunIdle();
  }

  Completer<void>? _inFlight; // F5/D1: 재진입 가드

  Future<void> run(String code, String language) {
    // F5/D1 반영: 진행 중이면 무시 — 연속 호출로 이전 Completer가 미완료 hang되는 것을 방지.
    if (_inFlight != null && !_inFlight!.isCompleted) return _inFlight!.future;

    _sub?.cancel();
    _sessionId = null;
    final done = Completer<void>();
    _inFlight = done;
    state = const RunRunning();

    _sub = ref
        .read(sandboxRunConnectProvider)(code, language)
        .listen(
          (e) {
            if (e.event == 'session') {
              _sessionId = int.tryParse(e.data);
              return;
            }
            final s = state;
            if (s is RunRunning) state = s.appended(e.data);
          },
          onError: (Object err) {
            if (err is ApiException &&
                err.code == ApiErrorCode.sandboxUnavailable) {
              state = const RunUnavailable();
            } else {
              final msg = err is ApiException ? err.message : err.toString();
              state = RunDone(
                logs: [..._logsOf(state), '실행 오류: $msg'],
                sandboxSessionId: _sessionId,
              );
            }
            if (!done.isCompleted) done.complete();
          },
          onDone: () {
            final s = state;
            if (s is RunRunning) {
              state = RunDone(logs: s.logs, sandboxSessionId: _sessionId);
            }
            if (!done.isCompleted) done.complete();
          },
          cancelOnError: true,
        );

    return done.future;
  }

  List<String> _logsOf(RunState s) =>
      s is RunRunning ? [...s.logs] : (s is RunDone ? [...s.logs] : <String>[]);
}

final runControllerProvider = NotifierProvider<RunController, RunState>(
  RunController.new,
);
