import 'package:devpath_web/src/features/review/state/review_state.dart';
import 'package:devpath_web/src/features/sandbox/application/sandbox_funnel_analytics.dart';
import 'package:devpath_web/src/features/sandbox/state/run_state.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_test/flutter_test.dart';

const _result = SandboxTerminalResult(
  sessionId: 91,
  status: SandboxSessionStatus.completed,
  exitCode: 0,
  truncated: false,
);

void main() {
  test('practice eligibility는 persisted COMPLETED만 run id를 준다', () {
    expect(
      persistedCompletedRunId(
        const RunCompleted(result: _result, persisted: true),
      ),
      91,
    );
    expect(
      persistedCompletedRunId(const RunCompleted(result: _result)),
      isNull,
    );
    expect(
      persistedCompletedRunId(
        const RunFailed(
          result: SandboxTerminalResult(
            sessionId: 91,
            status: SandboxSessionStatus.failed,
            exitCode: 1,
            truncated: false,
          ),
          persisted: true,
        ),
      ),
      isNull,
    );
  });

  test(
    'review eligibility는 explicit run과 exact session의 positive DB id만 준다',
    () {
      const explicit = RunCompleted(
        result: _result,
        persisted: true,
        explicitRun: true,
      );
      expect(
        contextualReviewId(
          run: explicit,
          review: const ReviewLoaded(
            CodeReview(id: '501', status: 'DONE', confidence: 80),
            sessionId: 91,
          ),
        ),
        501,
      );

      for (final review in <ReviewState>[
        const ReviewLoaded(
          CodeReview(status: 'DONE', confidence: 80),
          sessionId: 91,
        ),
        const ReviewLoaded(
          CodeReview(id: 'invalid', status: 'DONE', confidence: 80),
          sessionId: 91,
        ),
        const ReviewLoaded(
          CodeReview(id: '9007199254740992', status: 'DONE', confidence: 80),
          sessionId: 91,
        ),
        const ReviewLoaded(
          CodeReview(id: '501', status: 'DONE', confidence: 80),
          sessionId: 92,
        ),
        const ReviewLoading(sessionId: 91),
        const ReviewFailed('failed', sessionId: 91),
      ]) {
        expect(contextualReviewId(run: explicit, review: review), isNull);
      }
      expect(
        contextualReviewId(
          run: const RunCompleted(result: _result, explicitRun: false),
          review: const ReviewLoaded(
            CodeReview(id: '501', status: 'DONE', confidence: 80),
            sessionId: 91,
          ),
        ),
        isNull,
      );
    },
  );
}
