import 'dart:async';

import 'package:devpath_web/src/features/dashboard/application/current_mission_controller.dart';
import 'package:devpath_web/src/features/mission/state/mission_workspace_key.dart';
import 'package:devpath_web/src/features/review/application/review_controller.dart';
import 'package:devpath_web/src/features/review/state/review_state.dart';
import 'package:devpath_web/src/features/sandbox/application/run_controller.dart';
import 'package:devpath_web/src/features/sandbox/application/sandbox_workspace_controller.dart';
import 'package:devpath_web/src/features/sandbox/application/sandbox_workspace_retention.dart';
import 'package:devpath_web/src/features/sandbox/data/sandbox_run_source.dart';
import 'package:devpath_web/src/features/sandbox/state/run_state.dart';
import 'package:devpath_web/src/features/sandbox/state/sandbox_workspace_context.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const a = MissionWorkspaceKey(taskId: 1, contentId: 11);
const b = MissionWorkspaceKey(taskId: 2, contentId: 22);
const c = MissionWorkspaceKey(taskId: 3, contentId: 33);

final _ownerProvider = NotifierProvider<_OwnerController, String?>(
  _OwnerController.new,
);

final class _OwnerController extends Notifier<String?> {
  @override
  String? build() => 'owner-a';

  void set(String value) => state = value;
}

SandboxWorkspaceContext _context(MissionWorkspaceKey key) =>
    SandboxWorkspaceContext.resolve(
      workspaceKey: key,
      content: LearningContent(
        id: key.contentId,
        slug: 'c-${key.contentId}',
        title: 'content ${key.contentId}',
        track: 'BACKEND_SPRING',
        markdown: '# content',
        progress: const ContentProgress(scrollPct: 0, dwellSec: 0),
      ),
      taskTitle: 'task ${key.taskId}',
    );

void main() {
  test('A→B→A는 유지하고 세 번째 touch는 가장 오래된 workspace를 폐기한다', () async {
    final container = ProviderContainer(
      overrides: [
        currentMissionOwnerKeyProvider.overrideWith(
          (ref) => ref.watch(_ownerProvider),
        ),
      ],
    );
    addTearDown(container.dispose);
    final retention = container.read(
      sandboxWorkspaceRetentionProvider.notifier,
    );
    for (final key in [a, b]) {
      container
          .read(sandboxWorkspaceControllerProvider(key).notifier)
          .configure(_context(key));
      retention.touch(key);
    }
    container.read(reviewControllerFamilyProvider(b));
    container
        .read(sandboxWorkspaceControllerProvider(a).notifier)
        .updateCode('draft-a');

    retention.touch(a);
    expect(
      container.read(sandboxWorkspaceControllerProvider(a)).code,
      'draft-a',
    );

    retention.touch(c);
    expect(container.read(sandboxWorkspaceRetentionProvider), [a, c]);
    expect(
      container.read(sandboxWorkspaceControllerProvider(b)).context,
      isNull,
    );
    await container
        .read(reviewControllerFamilyProvider(b).notifier)
        .pollForSession(1, maxAttempts: 0);
    expect(
      container.read(reviewControllerFamilyProvider(b)),
      isA<ReviewFailed>(),
    );
  });

  test('evicted A의 late stream은 새 A state를 바꾸지 않는다', () async {
    final stream = StreamController<SseEvent>();
    final container = ProviderContainer(
      overrides: [
        currentMissionOwnerKeyProvider.overrideWithValue('owner-a'),
        sandboxRunV2ConnectProvider.overrideWithValue((_) => stream.stream),
      ],
    );
    addTearDown(() async {
      await stream.close();
      container.dispose();
    });
    final retention = container.read(
      sandboxWorkspaceRetentionProvider.notifier,
    );
    final pending = container
        .read(runControllerFamilyProvider(a).notifier)
        .run('class Main {}', 'JAVA');
    retention.touch(a);
    retention.touch(b);
    retention.touch(c);
    await pending;

    stream.add(const SseEvent(event: 'session', data: '99'));
    await Future<void>.delayed(Duration.zero);
    expect(container.read(runControllerFamilyProvider(a)), isA<RunIdle>());
  });

  test('owner switch는 retained workspace를 모두 폐기한다', () async {
    final container = ProviderContainer(
      overrides: [
        currentMissionOwnerKeyProvider.overrideWith(
          (ref) => ref.watch(_ownerProvider),
        ),
      ],
    );
    addTearDown(container.dispose);
    final retention = container.read(
      sandboxWorkspaceRetentionProvider.notifier,
    );
    for (final key in [a, b]) {
      container
          .read(sandboxWorkspaceControllerProvider(key).notifier)
          .configure(_context(key));
      retention.touch(key);
    }
    container.read(reviewControllerFamilyProvider(a));

    container.read(_ownerProvider.notifier).set('owner-b');

    expect(container.read(sandboxWorkspaceRetentionProvider), isEmpty);
    expect(
      container.read(sandboxWorkspaceControllerProvider(a)).context,
      isNull,
    );
    expect(
      container.read(sandboxWorkspaceControllerProvider(b)).context,
      isNull,
    );
    await container
        .read(reviewControllerFamilyProvider(a).notifier)
        .pollForSession(1, maxAttempts: 0);
    expect(
      container.read(reviewControllerFamilyProvider(a)),
      isA<ReviewFailed>(),
    );
  });
}
