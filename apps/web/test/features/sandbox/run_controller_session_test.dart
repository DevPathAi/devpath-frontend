import 'package:devpath_web/src/features/sandbox/application/run_controller.dart';
import 'package:devpath_web/src/features/sandbox/data/sandbox_run_source.dart';
import 'package:devpath_web/src/features/sandbox/state/run_state.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('captures sandboxSessionId from session SSE event', () async {
    final container = ProviderContainer(overrides: [
      sandboxRunConnectProvider.overrideWithValue((code, language) async* {
        yield const SseEvent(event: 'log', data: 'compiling');
        yield const SseEvent(event: 'session', data: '99');
      }),
    ]);
    addTearDown(container.dispose);

    await container.read(runControllerProvider.notifier).run('x', 'PYTHON');

    final s = container.read(runControllerProvider);
    expect(s, isA<RunDone>());
    expect((s as RunDone).sandboxSessionId, 99);
    expect(s.logs, contains('compiling'));
  });
}
