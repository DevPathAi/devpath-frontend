import 'package:devpath_web/src/app/router.dart';
import 'package:devpath_web/src/features/auth/state/auth_state.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_test/flutter_test.dart';

User _user(OnboardingStatus s, {ConsentStatus consent = ConsentStatus.done}) =>
    User(
      id: 'u',
      email: 'e@x.com',
      nickname: 'n',
      role: UserRole.learner,
      onboardingStatus: s,
      consentStatus: consent,
    );

void main() {
  group('gateRedirect', () {
    test('미인증 + 보호경로 → /login', () {
      expect(gateRedirect(const AuthUnauthenticated(), '/dashboard'), '/login');
    });
    test('미인증 + /login → 그대로(null)', () {
      expect(gateRedirect(const AuthUnauthenticated(), '/login'), isNull);
    });
    test('인증 + 온보딩 미완 + 보호경로 → /diagnostic', () {
      expect(
        gateRedirect(
          AuthAuthenticated(_user(OnboardingStatus.pending)),
          '/dashboard',
        ),
        '/diagnostic',
      );
    });
    test('인증 + 온보딩 미완 + /diagnostic → 그대로(null)', () {
      expect(
        gateRedirect(
          AuthAuthenticated(_user(OnboardingStatus.pending)),
          '/diagnostic',
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
    test('인증 + 온보딩 완료 + /diagnostic → /path', () {
      expect(
        gateRedirect(
          AuthAuthenticated(_user(OnboardingStatus.done)),
          '/diagnostic',
        ),
        '/path',
      );
    });
    test('미인증 + /diagnostic → 통과(null) — guest 진단 진입 허용', () {
      expect(gateRedirect(const AuthUnauthenticated(), '/diagnostic'), isNull);
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

    // --- Task 3.5: AuthLoading 보류 케이스 ---
    test('AuthLoading + 보호경로 → null(보류) — 세션 복원 판정 중', () {
      expect(gateRedirect(const AuthLoading(), '/dashboard'), isNull);
    });
    test('AuthLoading + /login → null(보류)', () {
      expect(gateRedirect(const AuthLoading(), '/login'), isNull);
    });
    test('AuthLoading + /auth/callback → null(보류)', () {
      expect(gateRedirect(const AuthLoading(), '/auth/callback'), isNull);
    });
    test('AuthLoading + /diagnostic → null(보류)', () {
      expect(gateRedirect(const AuthLoading(), '/diagnostic'), isNull);
    });

    // --- Task 4: consent 게이트 (onboarding보다 앞) ---
    test('인증 + 동의 미완(PENDING) + 보호경로 → /consent', () {
      expect(
        gateRedirect(
          AuthAuthenticated(
            _user(OnboardingStatus.done, consent: ConsentStatus.pending),
          ),
          '/dashboard',
        ),
        '/consent',
      );
    });
    test('인증 + 동의 미완 + /consent → 그대로(null)', () {
      expect(
        gateRedirect(
          AuthAuthenticated(
            _user(OnboardingStatus.done, consent: ConsentStatus.pending),
          ),
          '/consent',
        ),
        isNull,
      );
    });
    test('인증 + 동의 미완 → consent가 onboarding보다 우선(/consent)', () {
      // onboarding도 pending이지만 consent 게이트가 앞서므로 /consent로.
      expect(
        gateRedirect(
          AuthAuthenticated(
            _user(OnboardingStatus.pending, consent: ConsentStatus.pending),
          ),
          '/dashboard',
        ),
        '/consent',
      );
    });
    test('인증 + 동의 완료 + 온보딩 미완 + /consent → /diagnostic', () {
      // consent 완료면 /consent에 머무르지 않고 onboarding 게이트(진단)로.
      expect(
        gateRedirect(
          AuthAuthenticated(
            _user(OnboardingStatus.pending, consent: ConsentStatus.done),
          ),
          '/consent',
        ),
        '/diagnostic',
      );
    });
    test('인증 + 동의 완료 + 온보딩 완료 + /consent → /path', () {
      // consent·onboarding 모두 완료면 /consent 접근 시 정상 홈(/path)로.
      expect(
        gateRedirect(
          AuthAuthenticated(
            _user(OnboardingStatus.done, consent: ConsentStatus.done),
          ),
          '/consent',
        ),
        '/path',
      );
    });
  });
}
