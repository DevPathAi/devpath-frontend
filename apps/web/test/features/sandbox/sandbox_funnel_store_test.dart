import 'package:devpath_web/src/features/mission/state/mission_workspace_key.dart';
import 'package:devpath_web/src/features/sandbox/data/sandbox_funnel_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const workspace = MissionWorkspaceKey(taskId: 31, contentId: 3);

  test('first practice claim은 reload/owner 왕복에도 user+task당 한 번이다', () {
    final values = <String>{};
    final firstPage = MemorySandboxFunnelStore(values);
    expect(
      firstPage.claimFirstPractice(
        userId: '73',
        workspaceKey: workspace,
        runId: 91,
      ),
      isTrue,
    );
    expect(
      firstPage.claimFirstPractice(
        userId: '74',
        workspaceKey: workspace,
        runId: 92,
      ),
      isTrue,
    );

    final reloadedPage = MemorySandboxFunnelStore(values);
    expect(
      reloadedPage.claimFirstPractice(
        userId: '73',
        workspaceKey: workspace,
        runId: 93,
      ),
      isFalse,
    );
  });

  test('review claim은 positive review별 한 번이고 invalid ID를 거부한다', () {
    final store = MemorySandboxFunnelStore();
    expect(
      store.claimContextualReview(
        userId: '73',
        workspaceKey: workspace,
        sandboxSessionId: 91,
        reviewId: 501,
      ),
      isTrue,
    );
    expect(
      store.claimContextualReview(
        userId: '73',
        workspaceKey: workspace,
        sandboxSessionId: 91,
        reviewId: 501,
      ),
      isFalse,
    );
    expect(
      () => store.claimContextualReview(
        userId: '73',
        workspaceKey: workspace,
        sandboxSessionId: 91,
        reviewId: 0,
      ),
      throwsArgumentError,
    );
    expect(
      () => store.claimFirstPractice(
        userId: 'not-a-platform-id',
        workspaceKey: workspace,
        runId: 91,
      ),
      throwsArgumentError,
    );
  });
}
