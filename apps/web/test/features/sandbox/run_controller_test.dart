import 'package:devpath_web/src/features/sandbox/application/run_controller.dart';
import 'package:devpath_web/src/features/sandbox/data/sandbox_run_source.dart';
import 'package:devpath_web/src/features/sandbox/state/run_state.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Stream<SseEvent> _logs(List<String> lines) async* {
  for (final l in lines) {
    yield SseEvent(event: 'log', data: l);
  }
}

void main() {
  test('실행: 로그를 누적하고 done', () async {
    final c = ProviderContainer(
      overrides: [
        sandboxRunConnectProvider.overrideWithValue(
          (_) => _logs(['컴파일 중…', '테스트 통과']),
        ),
      ],
    );
    addTearDown(c.dispose);

    await c.read(runControllerProvider.notifier).run('print(1);');

    final s = c.read(runControllerProvider);
    expect(s, isA<RunDone>());
    expect((s as RunDone).logs, ['컴파일 중…', '테스트 통과']);
  });

  test('SANDBOX_UNAVAILABLE이면 RunUnavailable', () async {
    final c = ProviderContainer(
      overrides: [
        sandboxRunConnectProvider.overrideWithValue(
          (_) => Stream<SseEvent>.error(
            const ApiException(
              code: ApiErrorCode.sandboxUnavailable,
              message: '점검',
            ),
          ),
        ),
      ],
    );
    addTearDown(c.dispose);

    await c.read(runControllerProvider.notifier).run('print(1);');
    expect(c.read(runControllerProvider), isA<RunUnavailable>());
  });

  // F5/D1 반영: 재진입 가드 — 실행 중 재호출은 이전 Completer를 hang시키지 않는다.
  test('실행 중 재호출은 무시(재진입 가드)', () async {
    var connects = 0;
    final c = ProviderContainer(
      overrides: [
        sandboxRunConnectProvider.overrideWithValue((_) {
          connects++;
          return _logs(['1회차']);
        }),
      ],
    );
    addTearDown(c.dispose);

    final notifier = c.read(runControllerProvider.notifier);
    final first = notifier.run('print(1);');
    final second = notifier.run('print(2);'); // 진행 중 재호출 → 무시
    await Future.wait([first, second]);

    expect(connects, 1); // 두 번째 호출은 새 스트림을 만들지 않음
  });
}
