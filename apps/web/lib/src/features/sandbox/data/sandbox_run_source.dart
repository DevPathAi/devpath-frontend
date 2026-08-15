import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/api_providers.dart';

/// 실행 로그 SSE 스트림 생성기.
/// D-3 반영: language 파라미터 추가(JAVA/NODE/PYTHON). 목 분기는 무시.
/// 테스트 override는 `(code, language) => stream` 형태.
typedef SandboxRunConnect =
    Stream<SseEvent> Function(String code, String language);

typedef SandboxRunV2Connect =
    Stream<SseEvent> Function(SandboxRunRequest request);

typedef SandboxSessionRead = Future<SandboxSession> Function(int sessionId);

List<String> _mockRunLog(SandboxLanguage language) => [
  switch (language) {
    SandboxLanguage.java => '> java Main',
    SandboxLanguage.node => '> node main.js',
    SandboxLanguage.python => '> python main.py',
  },
  '컴파일 중…',
  '테스트 1/2 통과',
  '테스트 2/2 통과',
  '완료 (0.8s)',
];

final class _MockSandboxSessions {
  final _sessions = <int, SandboxSession>{};

  void complete(int sessionId, SandboxRunRequest request, List<String> logs) {
    final finishedAt = DateTime.now().toUtc();
    _sessions[sessionId] = SandboxSession(
      sessionId: sessionId,
      language: request.language,
      contentId: request.contentId,
      codeBlockId: request.codeBlockId,
      stdout: '${logs.join('\n')}\n',
      stderr: '',
      exitCode: 0,
      status: SandboxSessionStatus.completed,
      truncated: false,
      startedAt: finishedAt.subtract(const Duration(milliseconds: 800)),
      finishedAt: finishedAt,
    );
  }

  Future<SandboxSession> read(int sessionId) async {
    final session = _sessions[sessionId];
    if (session == null) {
      throw StateError('Unknown mock Sandbox session: $sessionId');
    }
    return session;
  }
}

final _sandboxMockSessionsProvider = Provider<_MockSandboxSessions>(
  (_) => _MockSandboxSessions(),
);

final sandboxRunConnectProvider = Provider<SandboxRunConnect>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.useMock) {
    return (String code, String language) async* {
      final logs = _mockRunLog(SandboxLanguage.fromWire(language));
      for (final line in logs) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        yield SseEvent(event: 'log', data: line);
      }
      yield const SseEvent(event: 'session', data: '1');
    };
  }
  // 실API: body에 code + language 포함(설계서 §5 D-3).
  final client = ref.watch(apiClientProvider);
  return (String code, String language) =>
      client.sse('/sandbox/run', body: {'code': code, 'language': language});
});

/// Mission workspace v2 contract. Legacy `/sandbox` intentionally does not
/// read this provider, which keeps the feature-OFF/current journey at zero new
/// request headers, context identifiers, and recovery calls.
final sandboxRunV2ConnectProvider = Provider<SandboxRunV2Connect>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.useMock) {
    final sessions = ref.watch(_sandboxMockSessionsProvider);
    return (SandboxRunRequest request) async* {
      final logs = _mockRunLog(request.language);
      yield const SseEvent(event: 'session', data: '1');
      // Real v2 projects the early response header and then receives the
      // legacy session event. Keep the duplicate here so mock mode exercises
      // the same idempotency path.
      yield const SseEvent(event: 'session', data: '1');
      for (final line in logs) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        yield SseEvent(event: 'log', data: line);
      }
      sessions.complete(1, request, logs);
      yield const SseEvent(
        event: 'result',
        data:
            '{"sessionId":1,"status":"COMPLETED",'
            '"exitCode":0,"truncated":false}',
      );
    };
  }
  final api = SandboxApi(ref.watch(apiClientProvider));
  return api.run;
});

final sandboxSessionReadProvider = Provider<SandboxSessionRead>((ref) {
  if (ref.watch(appConfigProvider).useMock) {
    return ref.watch(_sandboxMockSessionsProvider).read;
  }
  final api = SandboxApi(ref.watch(apiClientProvider));
  return api.session;
});
