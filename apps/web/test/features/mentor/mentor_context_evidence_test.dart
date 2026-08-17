import 'package:devpath_web/src/features/mentor/application/mentor_controller.dart';
import 'package:devpath_web/src/features/mentor/state/mentor_scope_key.dart';
import 'package:devpath_web/src/features/mission/state/mission_workspace_key.dart';
import 'package:devpath_web/src/features/review/application/review_controller.dart';
import 'package:devpath_web/src/features/review/state/review_state.dart';
import 'package:devpath_web/src/features/sandbox/application/run_controller.dart';
import 'package:devpath_web/src/features/sandbox/state/run_state.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _workspace = MissionWorkspaceKey(taskId: 31, contentId: 3);
const _scope = MentorScopeKey(ownerId: '73', workspaceKey: _workspace);

const _review = CodeReview(confidence: 91, strengths: ['old review']);

final _session = SandboxSession(
  sessionId: 91,
  language: SandboxLanguage.java,
  contentId: 3,
  codeBlockId: null,
  stdout: 'ok\n',
  stderr: '',
  exitCode: 0,
  status: SandboxSessionStatus.completed,
  truncated: false,
  startedAt: DateTime.utc(2026, 8, 16),
  finishedAt: DateTime.utc(2026, 8, 16, 0, 0, 1),
);

final _run = RunCompleted(
  result: const SandboxTerminalResult(
    sessionId: 91,
    status: SandboxSessionStatus.completed,
    exitCode: 0,
    truncated: false,
  ),
  persisted: true,
  session: _session,
);

final class _FixedRun extends RunController {
  _FixedRun(this.initial) : super(_workspace);

  final RunState initial;

  @override
  RunState build() => initial;
}

final class _FixedReview extends ReviewController {
  _FixedReview(this.initial) : super(_workspace);

  final ReviewState initial;

  @override
  ReviewState build() => initial;
}

ProviderContainer _container(ReviewState review) => ProviderContainer(
  overrides: [
    runControllerFamilyProvider(_workspace).overrideWith(() => _FixedRun(_run)),
    reviewControllerFamilyProvider(
      _workspace,
    ).overrideWith(() => _FixedReview(review)),
  ],
);

void main() {
  test('loading의 이전 review는 현재 실행의 exact review로 사용하지 않는다', () {
    final container = _container(
      const ReviewLoading(previous: _review, sessionId: 91),
    );
    addTearDown(container.dispose);

    final evidence = container.read(mentorContextEvidenceProvider(_scope));

    expect(evidence.session, same(_session));
    expect(evidence.review, isNull);
  });

  test('현재 session과 정확히 연결된 loaded review만 사용한다', () {
    final container = _container(const ReviewLoaded(_review, sessionId: 91));
    addTearDown(container.dispose);

    final evidence = container.read(mentorContextEvidenceProvider(_scope));

    expect(evidence.review, same(_review));
  });
}
