import 'package:devpath_mobile/src/app/router.dart';
import 'package:devpath_mobile/src/features/auth/state/auth_state.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_test/flutter_test.dart';

User _user() => const User(
  id: 'u1',
  email: 'a@b.c',
  nickname: '지수',
  role: UserRole.learner,
  onboardingStatus: OnboardingStatus.done,
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
  });
}
