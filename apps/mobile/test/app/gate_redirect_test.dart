import 'package:devpath_mobile/src/app/router.dart';
import 'package:devpath_mobile/src/features/auth/state/auth_state.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_test/flutter_test.dart';

User _user({OnboardingStatus onboarding = OnboardingStatus.done}) => User(
  id: 'u1',
  email: 'a@b.c',
  nickname: '지수',
  role: UserRole.learner,
  onboardingStatus: onboarding,
  consentStatus: ConsentStatus.done,
);

void main() {
  group('gateRedirect', () {
    test('AuthLoading → 보류(null)', () {
      expect(gateRedirect(const AuthLoading(), '/home'), isNull);
    });

    test('미인증 + 보호경로 → /login', () {
      expect(gateRedirect(const AuthUnauthenticated(), '/home'), '/login');
      expect(gateRedirect(const AuthUnauthenticated(), '/community'), '/login');
    });

    test('미인증 + /login → 허용(null)', () {
      expect(gateRedirect(const AuthUnauthenticated(), '/login'), isNull);
    });

    test('인증 + /login → /home', () {
      expect(gateRedirect(AuthAuthenticated(_user()), '/login'), '/home');
    });

    test('인증 + 보호경로 → 허용(null)', () {
      expect(gateRedirect(AuthAuthenticated(_user()), '/home'), isNull);
      expect(gateRedirect(AuthAuthenticated(_user()), '/learn'), isNull);
    });

    test('인증 + 진단 미완료 + 보호경로 → 웹 activation handoff', () {
      final pending = AuthAuthenticated(
        _user(onboarding: OnboardingStatus.pending),
      );
      expect(gateRedirect(pending, '/home'), '/activation');
      expect(gateRedirect(pending, '/community'), '/activation');
    });

    test('인증 + 진단 미완료 + /activation → 허용(null)', () {
      final pending = AuthAuthenticated(
        _user(onboarding: OnboardingStatus.pending),
      );
      expect(gateRedirect(pending, '/activation'), isNull);
    });

    test('인증 + 진단 완료 + /activation → /home', () {
      expect(gateRedirect(AuthAuthenticated(_user()), '/activation'), '/home');
    });
  });
}
