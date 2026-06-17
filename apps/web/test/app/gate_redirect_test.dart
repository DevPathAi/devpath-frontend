import 'package:devpath_web/src/app/router.dart';
import 'package:devpath_web/src/features/auth/state/auth_state.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_test/flutter_test.dart';

User _user(OnboardingStatus s) => User(
  id: 'u',
  email: 'e@x.com',
  nickname: 'n',
  role: UserRole.learner,
  onboardingStatus: s,
);

void main() {
  group('gateRedirect', () {
    test('미인증 + 보호경로 → /login', () {
      expect(gateRedirect(const AuthUnauthenticated(), '/dashboard'), '/login');
    });
    test('미인증 + /login → 그대로(null)', () {
      expect(gateRedirect(const AuthUnauthenticated(), '/login'), isNull);
    });
    test('인증 + 온보딩 미완 + 보호경로 → /onboarding', () {
      expect(
        gateRedirect(
          AuthAuthenticated(_user(OnboardingStatus.pending)),
          '/dashboard',
        ),
        '/onboarding',
      );
    });
    test('인증 + 온보딩 미완 + /onboarding → 그대로(null)', () {
      expect(
        gateRedirect(
          AuthAuthenticated(_user(OnboardingStatus.pending)),
          '/onboarding',
        ),
        isNull,
      );
    });
    test('인증 + 온보딩 완료 + /login → /dashboard', () {
      expect(
        gateRedirect(AuthAuthenticated(_user(OnboardingStatus.done)), '/login'),
        '/dashboard',
      );
    });
    test('인증 + 온보딩 완료 + 보호경로 → 그대로(null)', () {
      expect(
        gateRedirect(
          AuthAuthenticated(_user(OnboardingStatus.done)),
          '/dashboard',
        ),
        isNull,
      );
    });
    test('인증 + 온보딩 완료 + /onboarding → /path(게이트가 직접 리다이렉트)', () {
      expect(
        gateRedirect(
          AuthAuthenticated(_user(OnboardingStatus.done)),
          '/onboarding',
        ),
        '/path',
      );
    });
    test('미인증 + /auth/callback → 통과(null) — bootstrapFromCallback 진행 중', () {
      expect(
        gateRedirect(const AuthUnauthenticated(), '/auth/callback'),
        isNull,
      );
    });
    test('인증 + /auth/callback → 통과(null)', () {
      expect(
        gateRedirect(
          AuthAuthenticated(_user(OnboardingStatus.done)),
          '/auth/callback',
        ),
        isNull,
      );
    });
  });
}
