import 'package:devpath_web/src/app/router.dart';
import 'package:devpath_web/src/features/auth/state/auth_state.dart';
import 'package:devpath_web/src/features/mentor/application/mentor_invite_handoff.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Regression: ISSUE-005 — redirect re-entry consumed /mentor, then chose /path.
  // Found by /qa on 2026-09-08.
  // Report: .gstack/qa-reports/qa-report-127.0.0.1-2026-09-08.md
  test('초대 복귀 목적지는 redirect 재평가가 끝날 때까지 안정적으로 유지된다', () {
    final auth = AuthAuthenticated(
      User(
        id: 'u',
        email: 'learner@example.com',
        nickname: '학습자',
        role: UserRole.learner,
        onboardingStatus: OnboardingStatus.done,
        consentStatus: ConsentStatus.done,
      ),
    );
    final handoff = MemoryMentorInviteHandoffStore()
      ..rememberReturnTo('/mentor');
    final gateDestination = gateRedirect(auth, '/diagnostic');

    final first = mentorInviteReturnRedirect(
      auth: auth,
      location: '/diagnostic',
      gateDestination: gateDestination,
      handoff: handoff,
    );
    expect(first, '/mentor');
    expect(handoff.takeReturnTo(), isNull, reason: '세션 값은 한 번만 소비한다');

    final repeated = mentorInviteReturnRedirect(
      auth: auth,
      location: '/diagnostic',
      gateDestination: gateDestination,
      handoff: handoff,
      inFlightDestination: first,
    );
    expect(repeated, '/mentor');

    final committed = mentorInviteReturnRedirect(
      auth: auth,
      location: '/mentor',
      gateDestination: gateRedirect(auth, '/mentor'),
      handoff: handoff,
      inFlightDestination: first,
    );
    expect(committed, isNull);
  });
}
