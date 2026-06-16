import 'package:devpath_web/src/app/app.dart';
import 'package:devpath_web/src/features/auth/presentation/login_page.dart';
import 'package:devpath_web/src/features/onboarding/presentation/onboarding_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('초기에는 로그인, 로그인하면 온보딩으로 게이트된다', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: DevPathWebApp()));
    await tester.pumpAndSettle();

    // 미인증 → 로그인으로 redirect
    expect(find.byType(LoginPage), findsOneWidget);

    // 목 로그인(PENDING 유저) → 온보딩으로 redirect
    await tester.tap(find.text('GitHub로 계속하기 (목)'));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingPage), findsOneWidget);
  });
}
