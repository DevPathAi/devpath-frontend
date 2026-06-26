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

    test('인증 + 온보딩 미완료 + 보호경로 → /onboarding', () {
      final pending = AuthAuthenticated(
        _user(onboarding: OnboardingStatus.pending),
      );
      expect(gateRedirect(pending, '/home'), '/onboarding');
      expect(gateRedirect(pending, '/community'), '/onboarding');
    });

    test('인증 + 온보딩 미완료 + /onboarding → 허용(null)', () {
      final pending = AuthAuthenticated(
        _user(onboarding: OnboardingStatus.pending),
      );
      expect(gateRedirect(pending, '/onboarding'), isNull);
    });

    test('인증 + 온보딩 완료 + /onboarding → /home', () {
      expect(gateRedirect(AuthAuthenticated(_user()), '/onboarding'), '/home');
    });
  });
}
