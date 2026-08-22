import 'package:devpath_web/src/features/mission/state/mission_workspace_key.dart';
import 'package:devpath_web/src/features/sandbox/application/sandbox_workspace_controller.dart';
import 'package:devpath_web/src/features/sandbox/state/sandbox_workspace_context.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

SandboxWorkspaceContext _context(MissionWorkspaceKey key, String track) =>
    SandboxWorkspaceContext.resolve(
      workspaceKey: key,
      content: LearningContent(
        id: key.contentId,
        slug: 'lesson-${key.contentId}',
        title: '단원 ${key.contentId}',
        track: track,
        markdown: '# lesson',
        progress: const ContentProgress(scrollPct: 0, dwellSec: 0),
      ),
      taskTitle: '과제 ${key.taskId}',
    );

void main() {
  const a = MissionWorkspaceKey(taskId: 1, contentId: 11);
  const b = MissionWorkspaceKey(taskId: 2, contentId: 22);

  test('context configure는 runtime과 generic starter를 같은 keyed draft에 둔다', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container
        .read(sandboxWorkspaceControllerProvider(a).notifier)
        .configure(_context(a, 'BACKEND_SPRING'));

    final state = container.read(sandboxWorkspaceControllerProvider(a));
    expect(state.language, SandboxLanguage.java);
    expect(state.code, SandboxLanguage.java.genericStarter);
    expect(state.context?.contentId, 11);
  });

  test('언어 변경은 untouched generic만 교체하고 편집 draft는 보존한다', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(
      sandboxWorkspaceControllerProvider(a).notifier,
    );
    notifier.configure(_context(a, 'BACKEND_SPRING'));

    notifier.selectLanguage(SandboxLanguage.node);
    expect(
      container.read(sandboxWorkspaceControllerProvider(a)).code,
      SandboxLanguage.node.genericStarter,
    );

    notifier.updateCode('const answer = 42;');
    notifier.selectLanguage(SandboxLanguage.python);
    final state = container.read(sandboxWorkspaceControllerProvider(a));
    expect(state.code, 'const answer = 42;');
    expect(state.draftNotice, contains('기존 편집 코드는 유지'));
  });

  test('A→B→A는 서로 다른 editor draft를 보존한다', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(sandboxWorkspaceControllerProvider(a).notifier)
        .configure(_context(a, 'BACKEND_SPRING'));
    container
        .read(sandboxWorkspaceControllerProvider(b).notifier)
        .configure(_context(b, 'PYTHON_BACKEND'));
    container
        .read(sandboxWorkspaceControllerProvider(a).notifier)
        .updateCode('class A {}');
    container
        .read(sandboxWorkspaceControllerProvider(b).notifier)
        .updateCode('print("B")');

    expect(
      container.read(sandboxWorkspaceControllerProvider(a)).code,
      'class A {}',
    );
    expect(
      container.read(sandboxWorkspaceControllerProvider(b)).code,
      'print("B")',
    );
  });
}
