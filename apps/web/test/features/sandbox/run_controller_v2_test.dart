import 'dart:async';
import 'dart:convert';

import 'package:devpath_web/src/features/dashboard/application/current_mission_controller.dart';
import 'package:devpath_web/src/features/mission/state/mission_workspace_key.dart';
import 'package:devpath_web/src/features/sandbox/application/run_controller.dart';
import 'package:devpath_web/src/features/sandbox/data/sandbox_run_source.dart';
import 'package:devpath_web/src/features/sandbox/data/sandbox_session_store.dart';
import 'package:devpath_web/src/features/sandbox/state/run_state.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _key = MissionWorkspaceKey(taskId: 7, contentId: 12);

SandboxSession _session(
  SandboxSessionStatus status, {
  int id = 91,
  bool truncated = false,
  String stdout = 'ok\n',
  String stderr = '',
}) => SandboxSession(
  sessionId: id,
  language: SandboxLanguage.python,
  contentId: 12,
  codeBlockId: null,
  stdout: stdout,
  stderr: stderr,
  exitCode: status == SandboxSessionStatus.completed ? 0 : 1,
  status: status,
  truncated: truncated,
  startedAt: DateTime.utc(2026, 8, 16),
  finishedAt: status.isTerminal ? DateTime.utc(2026, 8, 16, 0, 0, 1) : null,
);

Stream<SseEvent> _events(Iterable<SseEvent> events) async* {
  for (final event in events) {
    yield event;
  }
}

void main() {
  test(
    'canonical run은 route contentId/codeBlockId와 선택 runtime을 v2에 전달한다',
    () async {
      SandboxRunRequest? captured;
      final container = ProviderContainer(
        overrides: [
          currentMissionOwnerKeyProvider.overrideWithValue('test-user'),
          sandboxRunV2ConnectProvider.overrideWithValue((request) {
            captured = request;
            return _events([
              const SseEvent(event: 'session', data: '91'),
              SseEvent(
                event: 'result',
                data: jsonEncode({
                  'sessionId': 91,
                  'status': 'COMPLETED',
                  'exitCode': 0,
                  'truncated': false,
                }),
              ),
            ]);
          }),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(runControllerFamilyProvider(_key).notifier)
          .run('print("ok")', 'py');

      expect(captured!.language, SandboxLanguage.python);
      expect(captured!.contentId, 12);
      expect(captured!.codeBlockId, isNull);
      expect(
        container.read(runControllerFamilyProvider(_key)),
        isA<RunCompleted>(),
      );
    },
  );

  test('legacy provider는 기존 SSE만 사용하고 v2 계약 호출은 0회다', () async {
    var legacyCalls = 0;
    var v2Calls = 0;
    final container = ProviderContainer(
      overrides: [
        currentMissionOwnerKeyProvider.overrideWithValue('test-user'),
        sandboxRunConnectProvider.overrideWithValue((code, language) {
          legacyCalls += 1;
          return _events([const SseEvent(event: 'log', data: 'legacy')]);
        }),
        sandboxRunV2ConnectProvider.overrideWithValue((request) {
          v2Calls += 1;
          return const Stream.empty();
        }),
      ],
    );
    addTearDown(container.dispose);

    await container.read(runControllerProvider.notifier).run('x', 'JAVA');

    expect(legacyCalls, 1);
    expect(v2Calls, 0);
    expect(container.read(runControllerProvider), isA<RunDone>());
  });

  test(
    'v2 result는 completed/failed/killed/timed_out을 서로 다른 state로 보존한다',
    () async {
      for (final entry in <String, Type>{
        'COMPLETED': RunCompleted,
        'FAILED': RunFailed,
        'KILLED': RunKilled,
        'TIMED_OUT': RunTimedOut,
      }.entries) {
        final container = ProviderContainer(
          overrides: [
            currentMissionOwnerKeyProvider.overrideWithValue('test-user'),
            sandboxRunV2ConnectProvider.overrideWithValue(
              (_) => _events([
                const SseEvent(event: 'session', data: '91'),
                SseEvent(
                  event: 'result',
                  data: jsonEncode({
                    'sessionId': 91,
                    'status': entry.key,
                    'exitCode': entry.key == 'COMPLETED' ? 0 : 1,
                    'truncated': entry.key == 'TIMED_OUT',
                  }),
                ),
              ]),
            ),
          ],
        );

        await container
            .read(runControllerFamilyProvider(_key).notifier)
            .run('x', 'PYTHON');
        final state = container.read(runControllerFamilyProvider(_key));
        expect(state.runtimeType, entry.value);
        expect(state.sandboxSessionId, 91);
        if (entry.key == 'TIMED_OUT') expect(state.truncated, isTrue);
        container.dispose();
      }
    },
  );

  test('header와 legacy session이 같은 ID면 dedupe하고 다르면 fail-closed한다', () async {
    for (final mismatch in [false, true]) {
      final container = ProviderContainer(
        overrides: [
          currentMissionOwnerKeyProvider.overrideWithValue('test-user'),
          sandboxRunV2ConnectProvider.overrideWithValue(
            (_) => _events([
              const SseEvent(event: 'session', data: '91'),
              SseEvent(event: 'session', data: mismatch ? '92' : '91'),
              SseEvent(
                event: 'result',
                data: jsonEncode({
                  'sessionId': 91,
                  'status': 'COMPLETED',
                  'exitCode': 0,
                  'truncated': false,
                }),
              ),
            ]),
          ),
        ],
      );

      await container
          .read(runControllerFamilyProvider(_key).notifier)
          .run('x', 'JAVA');
      final state = container.read(runControllerFamilyProvider(_key));
      expect(
        state,
        mismatch ? isA<RunTransportAborted>() : isA<RunCompleted>(),
      );
      expect(state.sandboxSessionId, 91);
      container.dispose();
    }
  });

  test(
    'session 뒤 transport abort는 partial log를 지우지 않고 owner GET terminal을 복구한다',
    () async {
      final container = ProviderContainer(
        overrides: [
          currentMissionOwnerKeyProvider.overrideWithValue('test-user'),
          sandboxRunV2ConnectProvider.overrideWithValue((_) async* {
            yield const SseEvent(event: 'session', data: '91');
            yield const SseEvent(event: 'log', data: 'partial');
            throw const ApiException(
              code: ApiErrorCode.network,
              message: 'disconnected',
            );
          }),
          sandboxSessionReadProvider.overrideWithValue(
            (_) async => _session(SandboxSessionStatus.completed, stdout: ''),
          ),
          sandboxRecoveryDelayProvider.overrideWithValue(Duration.zero),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(runControllerFamilyProvider(_key).notifier)
          .run('x', 'PYTHON');

      final state = container.read(runControllerFamilyProvider(_key));
      expect(state, isA<RunCompleted>());
      expect(state.logs, contains('partial'));
    },
  );

  test(
    'session 뒤 unavailable/busy delivery error도 admission으로 내리지 않고 owner 복구한다',
    () async {
      for (final code in [
        ApiErrorCode.sandboxUnavailable,
        ApiErrorCode.sandboxBusy,
      ]) {
        var reads = 0;
        final container = ProviderContainer(
          overrides: [
            currentMissionOwnerKeyProvider.overrideWithValue('test-user'),
            sandboxRunV2ConnectProvider.overrideWithValue((_) async* {
              yield const SseEvent(event: 'session', data: '91');
              throw ApiException(code: code, message: 'delivery failed');
            }),
            sandboxSessionReadProvider.overrideWithValue((_) async {
              reads += 1;
              return _session(SandboxSessionStatus.completed);
            }),
            sandboxRecoveryDelayProvider.overrideWithValue(Duration.zero),
          ],
        );

        await container
            .read(runControllerFamilyProvider(_key).notifier)
            .run('x', 'PYTHON');
        expect(reads, 1);
        expect(
          container.read(runControllerFamilyProvider(_key)),
          isA<RunCompleted>(),
        );
        container.dispose();
      }
    },
  );

  test(
    'owner recovery transcript는 partial과 persisted의 최대 overlap 뒤 tail만 붙인다',
    () async {
      final container = ProviderContainer(
        overrides: [
          currentMissionOwnerKeyProvider.overrideWithValue('test-user'),
          sandboxRunV2ConnectProvider.overrideWithValue((_) async* {
            yield const SseEvent(event: 'session', data: '91');
            yield const SseEvent(event: 'log', data: 'a');
            yield const SseEvent(event: 'log', data: 'b');
            throw const ApiException(
              code: ApiErrorCode.network,
              message: 'disconnected',
            );
          }),
          sandboxSessionReadProvider.overrideWithValue(
            (_) async =>
                _session(SandboxSessionStatus.completed, stdout: 'a\nb\nc\n'),
          ),
          sandboxRecoveryDelayProvider.overrideWithValue(Duration.zero),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(runControllerFamilyProvider(_key).notifier)
          .run('x', 'PYTHON');

      expect(container.read(runControllerFamilyProvider(_key)).logs, [
        'a',
        'b',
        'c',
      ]);
    },
  );

  test(
    'terminal result 뒤 owner GET 1회로 delivery queue에서 빠진 persisted tail을 동기화한다',
    () async {
      var reads = 0;
      final container = ProviderContainer(
        overrides: [
          currentMissionOwnerKeyProvider.overrideWithValue('test-user'),
          sandboxRunV2ConnectProvider.overrideWithValue(
            (_) => _events([
              const SseEvent(event: 'session', data: '91'),
              const SseEvent(event: 'log', data: 'a'),
              SseEvent(
                event: 'result',
                data: jsonEncode({
                  'sessionId': 91,
                  'status': 'COMPLETED',
                  'exitCode': 0,
                  'truncated': false,
                }),
              ),
            ]),
          ),
          sandboxSessionReadProvider.overrideWithValue((_) async {
            reads += 1;
            return _session(
              SandboxSessionStatus.completed,
              stdout: 'a\nmissed-tail\n',
            );
          }),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(runControllerFamilyProvider(_key).notifier)
          .run('x', 'PYTHON');

      expect(reads, 1);
      expect(container.read(runControllerFamilyProvider(_key)).logs, [
        'a',
        'missed-tail',
      ]);
      final terminal =
          container.read(runControllerFamilyProvider(_key)) as RunTerminal;
      expect(terminal.persisted, isTrue);
      expect(terminal.explicitRun, isTrue);
    },
  );

  test('delivered result는 owner GET 확정 전 persisted success가 아니다', () async {
    final recovery = Completer<SandboxSession>();
    final container = ProviderContainer(
      overrides: [
        currentMissionOwnerKeyProvider.overrideWithValue('test-user'),
        sandboxRunV2ConnectProvider.overrideWithValue(
          (_) => _events([
            const SseEvent(event: 'session', data: '91'),
            const SseEvent(
              event: 'result',
              data:
                  '{"sessionId":91,"status":"COMPLETED",'
                  '"exitCode":0,"truncated":false}',
            ),
          ]),
        ),
        sandboxSessionReadProvider.overrideWithValue((_) => recovery.future),
      ],
    );
    addTearDown(container.dispose);

    final running = container
        .read(runControllerFamilyProvider(_key).notifier)
        .run('x', 'PYTHON');
    await Future<void>.delayed(Duration.zero);

    final delivered = container.read(runControllerFamilyProvider(_key));
    expect(delivered, isA<RunCompleted>());
    expect((delivered as RunTerminal).persisted, isFalse);
    expect(delivered.explicitRun, isTrue);

    recovery.complete(_session(SandboxSessionStatus.completed));
    await running;
    expect(
      (container.read(runControllerFamilyProvider(_key)) as RunTerminal)
          .persisted,
      isTrue,
    );
  });

  test('session 없는 transport abort는 실행 terminal로 위조하지 않는다', () async {
    final container = ProviderContainer(
      overrides: [
        currentMissionOwnerKeyProvider.overrideWithValue('test-user'),
        sandboxRunV2ConnectProvider.overrideWithValue(
          (_) => Stream.error(
            const ApiException(code: ApiErrorCode.network, message: 'offline'),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(runControllerFamilyProvider(_key).notifier)
        .run('x', 'PYTHON');

    expect(
      container.read(runControllerFamilyProvider(_key)),
      isA<RunTransportAborted>(),
    );
  });

  test(
    'reload restore는 owner별 저장 session을 GET하고 TIMED_OUT/truncated를 복원한다',
    () async {
      final store = MemorySandboxSessionStore()..write('user-1', _key, 91);
      var reads = 0;
      final container = ProviderContainer(
        overrides: [
          currentMissionOwnerKeyProvider.overrideWithValue('user-1'),
          sandboxSessionStoreProvider.overrideWithValue(store),
          sandboxSessionReadProvider.overrideWithValue((id) async {
            reads += 1;
            return _session(SandboxSessionStatus.timedOut, truncated: true);
          }),
          sandboxRecoveryDelayProvider.overrideWithValue(Duration.zero),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(runControllerFamilyProvider(_key).notifier)
          .restore();

      final state = container.read(runControllerFamilyProvider(_key));
      expect(reads, 1);
      expect(state, isA<RunTimedOut>());
      expect(state.truncated, isTrue);
      expect((state as RunTerminal).persisted, isTrue);
      expect(state.explicitRun, isFalse);
    },
  );

  test('output storm은 마지막 2,000 rendered lines만 유지한다', () async {
    final controller = StreamController<SseEvent>();
    final container = ProviderContainer(
      overrides: [
        currentMissionOwnerKeyProvider.overrideWithValue('test-user'),
        sandboxRunV2ConnectProvider.overrideWithValue((_) => controller.stream),
      ],
    );
    addTearDown(() {
      controller.close();
      container.dispose();
    });

    final future = container
        .read(runControllerFamilyProvider(_key).notifier)
        .run('x', 'PYTHON');
    controller.add(const SseEvent(event: 'session', data: '91'));
    for (var i = 0; i < 2100; i++) {
      controller.add(SseEvent(event: 'log', data: 'line-$i'));
    }
    controller.add(
      SseEvent(
        event: 'result',
        data: jsonEncode({
          'sessionId': 91,
          'status': 'COMPLETED',
          'exitCode': 0,
          'truncated': true,
        }),
      ),
    );
    await controller.close();
    await future;

    final state = container.read(runControllerFamilyProvider(_key));
    expect(state.logs, hasLength(2000));
    expect(state.logs.first, 'line-100');
    expect(state.logs.last, 'line-2099');
  });
}
