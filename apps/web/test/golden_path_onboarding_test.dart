import 'package:devpath_web/src/app/app.dart';
import 'package:devpath_web/src/features/auth/application/auth_controller.dart';
import 'package:devpath_web/src/features/auth/state/auth_state.dart';
import 'package:devpath_web/src/features/onboarding/presentation/onboarding_page.dart';
import 'package:devpath_web/src/features/path/data/path_sse_source.dart';
import 'package:devpath_web/src/features/path/presentation/path_page.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 테스트 전용 AuthController: build()가 AuthUnauthenticated를 즉시 반환해
/// bootstrapSession microtask 없이 로그인 화면에서 시작한다.
/// bootstrapFromCallback()은 목 모드 LoginPage가 호출하므로 super에 위임한다.
class _NoBootstrapAuthController extends AuthController {
  @override
  AuthState build() => const AuthUnauthenticated();
}

void main() {
  testWidgets('로그인 → 온보딩 진단 → PATH 생성까지 게이트 흐름', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(_NoBootstrapAuthController.new),
        ],
        child: const DevPathWebApp(),
      ),
    );
    await tester.pumpAndSettle();

    // 로그인(PENDING) → 온보딩
    await tester.tap(find.text('GitHub로 계속하기 (목)'));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingPage), findsOneWidget);

    // 진단 제출 → PATH 생성 화면
    await tester.enterText(find.byType(TextField), 'jisoo-dev');
    await tester.tap(find.text('진단 시작하기'));
    await tester.pumpAndSettle();
    expect(find.byType(PathPage), findsOneWidget);

    // 목 SSE(250ms×4) 완료까지 진행(pumpAndSettle이 흡수 못하는 타이머는 명시 pump).
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.textContaining('비동기 기초'), findsWidgets); // 생성 완료된 타임라인
  });

  testWidgets('D2: SSE 중단 주입 → "이어서 생성"(resume, fromStep:2) → 완료', (
    tester,
  ) async {
    // failAfter:2 → fromStep 기준 2단계(ANALYZE·MAP) 후 ApiException(network) 중단.
    // MockSseSource는 stages 전체 + fromStep 루프 시작이므로 sublist가 아니라 전체 kSseSteps 전달.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // Task 3.5: bootstrapSession microtask 없이 로그인 화면에서 시작.
          authControllerProvider.overrideWith(_NoBootstrapAuthController.new),
          pathSseConnectProvider.overrideWithValue(
            ({int fromStep = 0}) => MockSseSource(
              stages: kSseSteps,
              delay: const Duration(milliseconds: 10),
              failAfter: fromStep == 0 ? 2 : null, // 1회차만 중단, 이어하기는 정상
              fromStep: fromStep,
            ).stream(),
          ),
        ],
        child: const DevPathWebApp(),
      ),
    );
    await tester.pumpAndSettle();

    // 로그인 → 온보딩 → 진단 제출 → PATH 생성(중단)
    await tester.tap(find.text('GitHub로 계속하기 (목)'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'jisoo-dev');
    await tester.tap(find.text('진단 시작하기'));
    await tester.pumpAndSettle();

    // 중단 → 완료 단계 보존 + "이어서 생성" 노출
    expect(find.text('이어서 생성'), findsOneWidget);

    // 이어서 생성(fromStep:2) → 완료(타임라인)
    await tester.tap(find.text('이어서 생성'));
    await tester.pumpAndSettle();
    expect(find.textContaining('비동기 기초'), findsWidgets);
  });
}
