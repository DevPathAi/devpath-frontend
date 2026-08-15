import 'package:dp_core/dp_core.dart';

sealed class RunState {
  const RunState();

  List<String> get logs => const [];
  int? get sandboxSessionId => null;
  bool get truncated => false;
}

class RunIdle extends RunState {
  const RunIdle();
}

class RunRunning extends RunState {
  const RunRunning({
    this.logs = const [],
    this.sandboxSessionId,
    this.status = SandboxSessionStatus.running,
    this.recovering = false,
  });

  @override
  final List<String> logs;
  @override
  final int? sandboxSessionId;
  final SandboxSessionStatus status;
  final bool recovering;

  RunRunning copyWith({
    List<String>? logs,
    int? sandboxSessionId,
    SandboxSessionStatus? status,
    bool? recovering,
  }) => RunRunning(
    logs: logs ?? this.logs,
    sandboxSessionId: sandboxSessionId ?? this.sandboxSessionId,
    status: status ?? this.status,
    recovering: recovering ?? this.recovering,
  );

  RunRunning appended(String line) => copyWith(logs: [...logs, line]);
}

/// Completion inferred only by the legacy stream ending. The durable v2 path
/// never produces this state because transport completion is not execution
/// evidence.
class RunDone extends RunState {
  const RunDone({this.logs = const [], this.sandboxSessionId});

  @override
  final List<String> logs;
  @override
  final int? sandboxSessionId;
}

sealed class RunTerminal extends RunState {
  const RunTerminal({
    required this.result,
    this.logs = const [],
    this.persisted = false,
    this.explicitRun = false,
  });

  final SandboxTerminalResult result;

  /// True only after owner GET confirmed the persisted terminal row.
  final bool persisted;

  /// True when this session originated from the user's current Run action.
  /// Reload/session restore deliberately keeps this false.
  final bool explicitRun;
  int get approvedContextFieldCount => explicitRun ? 1 : 0;
  @override
  final List<String> logs;
  @override
  int get sandboxSessionId => result.sessionId;
  @override
  bool get truncated => result.truncated;
}

final class RunCompleted extends RunTerminal {
  const RunCompleted({
    required super.result,
    super.logs,
    super.persisted,
    super.explicitRun,
  });
}

final class RunFailed extends RunTerminal {
  const RunFailed({
    required super.result,
    super.logs,
    super.persisted,
    super.explicitRun,
  });
}

final class RunKilled extends RunTerminal {
  const RunKilled({
    required super.result,
    super.logs,
    super.persisted,
    super.explicitRun,
  });
}

final class RunTimedOut extends RunTerminal {
  const RunTimedOut({
    required super.result,
    super.logs,
    super.persisted,
    super.explicitRun,
  });
}

/// Admission/runtime infrastructure unavailable. This is not a run terminal.
final class RunUnavailable extends RunState {
  const RunUnavailable({this.logs = const [], this.message});

  @override
  final List<String> logs;
  final String? message;
}

/// Per-owner capacity rejection. This is not a run terminal.
final class RunBusy extends RunState {
  const RunBusy({this.logs = const [], this.retryAfterSeconds, this.message});

  @override
  final List<String> logs;
  final int? retryAfterSeconds;
  final String? message;
}

/// Delivery ended without durable terminal evidence. If a session ID exists,
/// owner recovery can be retried without clearing the editor or transcript.
final class RunTransportAborted extends RunState {
  const RunTransportAborted({
    this.logs = const [],
    this.sandboxSessionId,
    required this.message,
  });

  @override
  final List<String> logs;
  @override
  final int? sandboxSessionId;
  final String message;
}
