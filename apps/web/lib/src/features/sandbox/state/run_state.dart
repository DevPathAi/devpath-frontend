sealed class RunState {
  const RunState();
}

class RunIdle extends RunState {
  const RunIdle();
}

class RunRunning extends RunState {
  const RunRunning({this.logs = const []});
  final List<String> logs;
  RunRunning appended(String line) => RunRunning(logs: [...logs, line]);
}

class RunDone extends RunState {
  const RunDone({this.logs = const []});
  final List<String> logs;
}

/// SANDBOX_UNAVAILABLE(503) — 실행만 비활성, 편집 유지(DD4/§9.2).
class RunUnavailable extends RunState {
  const RunUnavailable();
}
