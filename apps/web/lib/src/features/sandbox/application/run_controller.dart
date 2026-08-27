import 'dart:async';
import 'dart:convert';

import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../dashboard/application/current_mission_controller.dart';
import '../../mission/state/mission_workspace_key.dart';
import '../data/sandbox_run_source.dart';
import '../data/sandbox_session_store.dart';
import '../state/run_state.dart';

final sandboxSessionStoreProvider = Provider<SandboxSessionStore>(
  (ref) => sandboxSessionStore(),
);
final sandboxRecoveryDelayProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 1),
);
final sandboxRecoveryMaxAttemptsProvider = Provider<int>((ref) => 36);

class RunController extends Notifier<RunState> {
  RunController(this.workspaceKey);

  static const maxRenderedLines = 2000;
  static const logBatchInterval = Duration(milliseconds: 50);

  final MissionWorkspaceKey? workspaceKey;
  StreamSubscription<SseEvent>? _sub;
  Timer? _logTimer;
  final _pendingLogs = <String>[];
  Completer<void>? _inFlight;
  int? _sessionId;
  int? _requestedCodeBlockId;
  SandboxLanguage? _requestedLanguage;
  String? _ownerKey;
  var _generation = 0;
  var _terminalReceived = false;
  var _explicitRun = false;
  var _disposed = false;

  bool get _durable => workspaceKey != null;

  @override
  RunState build() {
    _disposed = false;
    if (_durable) {
      _ownerKey = ref.read(currentMissionOwnerKeyProvider);
      ref.listen(currentMissionOwnerKeyProvider, (_, nextOwner) {
        if (_disposed || nextOwner == _ownerKey) return;
        _ownerKey = nextOwner;
        _resetForOwnerChange();
      });
    }
    ref.onDispose(() {
      _disposed = true;
      _generation += 1;
      _logTimer?.cancel();
      _pendingLogs.clear();
      unawaited(_sub?.cancel());
      _completeInFlight();
    });
    return const RunIdle();
  }

  Future<void> run(String code, String language, {int? codeBlockId}) {
    final active = _inFlight;
    if (active != null && !active.isCompleted) return active.future;

    final parsedLanguage = SandboxLanguage.fromWire(language);
    final request = SandboxRunRequest(
      code: code,
      language: parsedLanguage,
      contentId: workspaceKey?.contentId,
      codeBlockId: _durable ? codeBlockId : null,
    );
    _generation += 1;
    final generation = _generation;
    _terminalReceived = false;
    _explicitRun = true;
    _sessionId = null;
    _requestedLanguage = parsedLanguage;
    _requestedCodeBlockId = request.codeBlockId;
    _logTimer?.cancel();
    _pendingLogs.clear();
    unawaited(_sub?.cancel());
    state = RunRunning(
      status: _durable
          ? SandboxSessionStatus.allocating
          : SandboxSessionStatus.running,
    );

    final done = Completer<void>();
    _inFlight = done;
    final stream = _durable
        ? ref.read(sandboxRunV2ConnectProvider)(request)
        : ref.read(sandboxRunConnectProvider)(code, parsedLanguage.wireName);
    _sub = stream.listen(
      (event) => _onEvent(event, generation),
      onError: (Object error, StackTrace stackTrace) {
        unawaited(_onStreamError(error, generation));
      },
      onDone: () => unawaited(_onStreamDone(generation)),
      cancelOnError: true,
    );
    return done.future;
  }

  /// Restores only a server session identifier. User-authored code never enters
  /// route parameters or this persistence boundary.
  Future<void> restore() async {
    final key = workspaceKey;
    final owner = _ownerKey;
    if (key == null || owner == null || _isBusy) return;
    final sessionId = ref.read(sandboxSessionStoreProvider).read(owner, key);
    if (sessionId == null) return;
    _generation += 1;
    final generation = _generation;
    _explicitRun = false;
    _sessionId = sessionId;
    state = RunRunning(
      sandboxSessionId: sessionId,
      status: SandboxSessionStatus.allocating,
      recovering: true,
    );
    final done = Completer<void>();
    _inFlight = done;
    await _recover(sessionId, generation);
  }

  Future<void> retryRecovery() async {
    final sessionId = state.sandboxSessionId;
    if (!_durable || sessionId == null || _isBusy) return;
    _generation += 1;
    final generation = _generation;
    final done = Completer<void>();
    _inFlight = done;
    await _recover(sessionId, generation);
  }

  bool get _isBusy {
    final active = _inFlight;
    return active != null && !active.isCompleted;
  }

  void _onEvent(SseEvent event, int generation) {
    if (!_isCurrent(generation) || _terminalReceived) return;
    switch (event.event) {
      case 'session':
        _acceptSession(event.data, generation);
      case 'log':
        _queueLog(event.data);
      case 'result':
        _acceptResult(event.data, generation);
      default:
        // Heartbeats/comments and additive unknown frames do not mutate state.
        break;
    }
  }

  void _acceptSession(String raw, int generation) {
    final incoming = int.tryParse(raw);
    if (incoming == null ||
        incoming <= 0 ||
        incoming > MissionWorkspaceKey.maxSafeInteger) {
      _failProtocol('실행 세션 식별자를 확인하지 못했어요.', generation);
      return;
    }
    final current = _sessionId;
    if (current != null) {
      if (current != incoming) {
        _failProtocol('실행 세션 식별자가 서로 일치하지 않아요.', generation);
      }
      // Header projection followed by the legacy session frame is expected.
      return;
    }
    _sessionId = incoming;
    _storeSessionBestEffort(incoming);
    final running = state;
    if (running is RunRunning) {
      state = running.copyWith(
        sandboxSessionId: incoming,
        status: SandboxSessionStatus.allocating,
      );
    }
  }

  void _acceptResult(String raw, int generation) {
    _flushLogs();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) throw const FormatException('result must be map');
      final result = SandboxTerminalResult.fromJson(
        decoded.cast<String, Object?>(),
      );
      final current = _sessionId;
      if (current != null && current != result.sessionId) {
        _failProtocol('실행 결과의 세션 식별자가 일치하지 않아요.', generation);
        return;
      }
      _sessionId = result.sessionId;
      _storeSessionBestEffort(result.sessionId);
      _terminalReceived = true;
      final terminal = _terminalState(result, _logsOf(state), persisted: false);
      if (_durable) {
        state = terminal;
        unawaited(_syncTerminalResult(result, generation));
      } else {
        _finishInFlight(terminal);
      }
    } on Object {
      _failProtocol('실행 결과 형식을 확인하지 못했어요.', generation);
    }
  }

  void _failProtocol(String message, int generation) {
    if (!_isCurrent(generation)) return;
    _flushLogs();
    _terminalReceived = true;
    unawaited(_sub?.cancel());
    _finishInFlight(
      RunTransportAborted(
        logs: _logsOf(state),
        sandboxSessionId: _sessionId,
        message: message,
      ),
    );
  }

  Future<void> _onStreamError(Object error, int generation) async {
    if (!_isCurrent(generation) || _terminalReceived) return;
    _flushLogs();
    final logs = _logsOf(state);
    final sessionId = _sessionId;
    // Once admission returned a durable identity, every later socket/error
    // classification is delivery-only. Recover before interpreting 429/503.
    if (_durable && sessionId != null) {
      await _recover(sessionId, generation);
      return;
    }
    if (error is ApiException &&
        error.code == ApiErrorCode.sandboxUnavailable) {
      _finishInFlight(RunUnavailable(logs: logs, message: error.message));
      return;
    }
    if (error is ApiException && error.code == ApiErrorCode.sandboxBusy) {
      _finishInFlight(
        RunBusy(
          logs: logs,
          retryAfterSeconds: error.retryAfterSeconds,
          message: error.message,
        ),
      );
      return;
    }
    _finishInFlight(
      RunTransportAborted(
        logs: logs,
        sandboxSessionId: sessionId,
        message: error is ApiException ? error.message : '실행 스트림 연결이 중단되었어요.',
      ),
    );
  }

  Future<void> _onStreamDone(int generation) async {
    if (!_isCurrent(generation) || _terminalReceived) return;
    _flushLogs();
    if (!_durable) {
      _finishInFlight(
        RunDone(logs: _logsOf(state), sandboxSessionId: _sessionId),
      );
      return;
    }
    final sessionId = _sessionId;
    if (sessionId != null) {
      await _recover(sessionId, generation);
      return;
    }
    _finishInFlight(
      RunTransportAborted(
        logs: _logsOf(state),
        message: '실행이 종료되었지만 복구할 세션을 받지 못했어요.',
      ),
    );
  }

  Future<void> _recover(int sessionId, int generation) async {
    if (!_isCurrent(generation)) return;
    final previousLogs = _logsOf(state);
    state = RunRunning(
      logs: previousLogs,
      sandboxSessionId: sessionId,
      status: state is RunRunning
          ? (state as RunRunning).status
          : SandboxSessionStatus.running,
      recovering: true,
    );
    final attempts = ref.read(sandboxRecoveryMaxAttemptsProvider);
    for (var attempt = 0; attempt < attempts; attempt++) {
      if (!_isCurrent(generation)) return;
      try {
        final session = await ref.read(sandboxSessionReadProvider)(sessionId);
        if (!_isCurrent(generation)) return;
        if (!_validRecovery(session)) {
          _finishInFlight(
            RunTransportAborted(
              logs: _logsOf(state),
              sandboxSessionId: sessionId,
              message: '복구한 실행 맥락이 현재 미션과 일치하지 않아요.',
            ),
          );
          return;
        }
        final mergedLogs = _mergeRecoveredLogs(_logsOf(state), session);
        if (session.status.isTerminal) {
          final result = SandboxTerminalResult(
            sessionId: session.sessionId,
            status: session.status,
            exitCode: session.exitCode,
            truncated: session.truncated,
          );
          _terminalReceived = true;
          _finishInFlight(
            _terminalState(
              result,
              mergedLogs,
              persisted: true,
              session: session,
            ),
          );
          return;
        }
        state = RunRunning(
          logs: mergedLogs,
          sandboxSessionId: sessionId,
          status: session.status,
          recovering: true,
        );
        if (attempt + 1 < attempts) {
          await Future<void>.delayed(ref.read(sandboxRecoveryDelayProvider));
        }
      } on Object catch (error) {
        if (!_isCurrent(generation)) return;
        _finishInFlight(
          RunTransportAborted(
            logs: _logsOf(state),
            sandboxSessionId: sessionId,
            message: error is ApiException
                ? error.message
                : '실행 상태를 복구하지 못했어요.',
          ),
        );
        return;
      }
    }
    if (_isCurrent(generation)) {
      _finishInFlight(
        RunTransportAborted(
          logs: _logsOf(state),
          sandboxSessionId: sessionId,
          message: '실행이 아직 진행 중이에요. 잠시 후 다시 확인해 주세요.',
        ),
      );
    }
  }

  Future<void> _syncTerminalResult(
    SandboxTerminalResult delivered,
    int generation,
  ) async {
    try {
      final session = await ref.read(sandboxSessionReadProvider)(
        delivered.sessionId,
      );
      if (!_isCurrent(generation)) return;
      if (!_validRecovery(session) ||
          !session.status.isTerminal ||
          session.status != delivered.status) {
        _finishInFlight(
          RunTransportAborted(
            logs: _logsOf(state),
            sandboxSessionId: delivered.sessionId,
            message: '전달된 실행 결과와 저장된 실행 상태가 일치하지 않아요.',
          ),
        );
        return;
      }
      final persisted = SandboxTerminalResult(
        sessionId: session.sessionId,
        status: session.status,
        exitCode: session.exitCode,
        truncated: session.truncated,
      );
      _finishInFlight(
        _terminalState(
          persisted,
          _mergeRecoveredLogs(_logsOf(state), session),
          persisted: true,
          session: session,
        ),
      );
    } on Object {
      // The v2 result itself mirrors a persisted terminal row. A secondary GET
      // failure cannot relabel that execution; it only means tail sync failed.
      _completeInFlight();
    }
  }

  bool _validRecovery(SandboxSession session) {
    final key = workspaceKey;
    if (session.sessionId != _sessionId) return false;
    if (key != null && session.contentId != key.contentId) return false;
    if (_requestedCodeBlockId != null &&
        session.codeBlockId != _requestedCodeBlockId) {
      return false;
    }
    if (_requestedLanguage != null && session.language != _requestedLanguage) {
      return false;
    }
    return true;
  }

  List<String> _mergeRecoveredLogs(
    List<String> current,
    SandboxSession session,
  ) {
    final recovered = <String>[
      ...session.stdout.split('\n'),
      ...session.stderr.split('\n'),
    ].where((line) => line.isNotEmpty);
    if (recovered.isEmpty) return current;
    final recoveredLines = recovered.toList(growable: false);
    final maxOverlap = current.length < recoveredLines.length
        ? current.length
        : recoveredLines.length;
    var overlap = 0;
    for (var candidate = maxOverlap; candidate > 0; candidate--) {
      var matches = true;
      for (var index = 0; index < candidate; index++) {
        if (current[current.length - candidate + index] !=
            recoveredLines[index]) {
          matches = false;
          break;
        }
      }
      if (matches) {
        overlap = candidate;
        break;
      }
    }
    return _bounded([...current, ...recoveredLines.skip(overlap)]);
  }

  void _queueLog(String data) {
    _pendingLogs.addAll(data.split('\n'));
    _logTimer ??= Timer(logBatchInterval, () {
      _logTimer = null;
      _flushLogs();
    });
  }

  void _flushLogs() {
    _logTimer?.cancel();
    _logTimer = null;
    if (_pendingLogs.isEmpty) return;
    final incoming = List<String>.of(_pendingLogs);
    _pendingLogs.clear();
    final current = state;
    if (current is RunRunning) {
      state = current.copyWith(logs: _bounded([...current.logs, ...incoming]));
    }
  }

  List<String> _bounded(List<String> lines) => lines.length <= maxRenderedLines
      ? List.unmodifiable(lines)
      : List.unmodifiable(lines.sublist(lines.length - maxRenderedLines));

  RunTerminal _terminalState(
    SandboxTerminalResult result,
    List<String> logs, {
    required bool persisted,
    SandboxSession? session,
  }) => switch (result.status) {
    SandboxSessionStatus.completed => RunCompleted(
      result: result,
      logs: logs,
      persisted: persisted,
      explicitRun: _explicitRun,
      session: session,
    ),
    SandboxSessionStatus.failed => RunFailed(
      result: result,
      logs: logs,
      persisted: persisted,
      explicitRun: _explicitRun,
      session: session,
    ),
    SandboxSessionStatus.killed => RunKilled(
      result: result,
      logs: logs,
      persisted: persisted,
      explicitRun: _explicitRun,
      session: session,
    ),
    SandboxSessionStatus.timedOut => RunTimedOut(
      result: result,
      logs: logs,
      persisted: persisted,
      explicitRun: _explicitRun,
      session: session,
    ),
    SandboxSessionStatus.allocating ||
    SandboxSessionStatus.running => throw StateError('non-terminal result'),
  };

  List<String> _logsOf(RunState value) => List<String>.of(value.logs);

  void _storeSessionBestEffort(int sessionId) {
    final key = workspaceKey;
    final owner = _ownerKey;
    if (key == null || owner == null) return;
    try {
      ref.read(sandboxSessionStoreProvider).write(owner, key, sessionId);
    } on Object {
      // A storage denial cannot invalidate a server-accepted run.
    }
  }

  bool _isCurrent(int generation) => !_disposed && generation == _generation;

  void _completeInFlight() {
    final active = _inFlight;
    if (active != null && !active.isCompleted) active.complete();
  }

  void _finishInFlight(RunState next) {
    _completeInFlight();
    state = next;
  }

  void _resetForOwnerChange() {
    _generation += 1;
    _terminalReceived = false;
    _explicitRun = false;
    _sessionId = null;
    _requestedLanguage = null;
    _requestedCodeBlockId = null;
    _logTimer?.cancel();
    _pendingLogs.clear();
    unawaited(_sub?.cancel());
    _completeInFlight();
    state = const RunIdle();
  }
}

final runControllerFamilyProvider =
    NotifierProvider.family<RunController, RunState, MissionWorkspaceKey?>(
      RunController.new,
    );

/// Backward-compatible standalone `/sandbox` provider.
final runControllerProvider = runControllerFamilyProvider(null);
