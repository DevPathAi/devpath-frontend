import 'package:devpath_web/src/app/app.dart';
import 'package:devpath_web/src/features/auth/application/auth_controller.dart';
import 'package:devpath_web/src/features/auth/presentation/login_page.dart';
import 'package:devpath_web/src/features/auth/state/auth_state.dart';
import 'package:devpath_web/src/features/onboarding/presentation/onboarding_page.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 테스트 전용 AuthController:
/// - build()는 AuthUnauthenticated를 즉시 반환(bootstrapSession microtask 없음).
///   → 위젯 테스트가 항상 로그인 화면에서 시작한다.
/// - bootstrapFromCallback()은 목 AuthAuthenticated(pending 유저)를 직접 설정.
///   목 모드에서 LoginPage는 bootstrapFromCallback()을 호출하므로,
///   실 HTTP 호출 없이 게이트 흐름을 검증한다.
class _MockAuthController extends AuthController {
  @override
  AuthState build() => const AuthUnauthenticated();

  @override
  Future<void> bootstrapFromCallback() async {
    state = AuthAuthenticated(
      const User(
        id: 'u-mock',
        email: 'learner@devpath.ai',
        nickname: '지수',
        role: UserRole.learner,
        onboardingStatus: OnboardingStatus.pending,
      ),
    );
  }
}

void main() {
  testWidgets('초기에는 로그인, 로그인하면 온보딩으로 게이트된다', (tester) async {
    final container = ProviderContainer(
      overrides: [authControllerProvider.overrideWith(_MockAuthController.new)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const DevPathWebApp(),
      ),
    );
    await tester.pumpAndSettle();

    // 미인증 → 로그인으로 redirect
    expect(find.byType(LoginPage), findsOneWidget);

    // 목 로그인(PENDING 유저) → 온보딩으로 redirect. useMock=true(기본값)이므로 "(목)" 접미사.
    await tester.tap(find.text('GitHub로 계속하기 (목)'));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingPage), findsOneWidget);
  });
}
