import 'package:devpath_web/src/app/app.dart';
import 'package:devpath_web/src/features/auth/application/auth_controller.dart';
import 'package:devpath_web/src/features/auth/state/auth_state.dart';
import 'package:devpath_web/src/features/diagnostic/application/diagnostic_controller.dart';
import 'package:devpath_web/src/features/diagnostic/presentation/diagnostic_page.dart';
import 'package:devpath_web/src/features/path/presentation/path_page.dart';
import 'package:devpath_web/src/features/sandbox/data/sandbox_run_source.dart';
import 'package:devpath_web/src/features/sandbox/presentation/sandbox_page.dart';
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 골든패스(위젯 레벨 통합): 온보딩 로그인 → 진단 → PATH SSE 생성 → Sandbox 실행.
///
/// integration_test 패키지(별도 dev_dependency + 드라이버 러너)를 도입하는 대신,
/// 기존 golden_path_onboarding_test·content_sandbox_smoke_test와 동일한
/// 위젯 레벨 통합 패턴으로 골든패스 전 구간을 회귀 고정한다. flutter_test 스택만
/// 사용하므로 `flutter test`(melos run test)로 그대로 실행된다.

/// 테스트 전용 AuthController: build()가 AuthUnauthenticated를 즉시 반환해
/// bootstrapSession microtask 없이 로그인 화면에서 시작한다.
class _NoBootstrapAuthController extends AuthController {
  @override
  AuthState build() => const AuthUnauthenticated();
}

/// 즉시 완료되는 진단 API: next()=null로 바로 complete()로 진행.
class _FastCompleteAssessmentApi implements AssessmentApi {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);

  @override
  Future<int> startMember(String track) async => 1;

  @override
  Future<NextQuestion?> next({int? assessmentId, String? guestId}) async =>
      null;

  @override
  Future<AssessmentResult> complete({
    int? assessmentId,
    String? guestId,
  }) async =>
      const AssessmentResult(diagnosedLevel: 'MID', confidenceWeight: 0.8);
}

Stream<SseEvent> _logs(List<String> l) async* {
  for (final x in l) {
    yield SseEvent(event: 'log', data: x);
  }
}

void main() {
  testWidgets('골든패스: 로그인 → 진단 → PATH 생성 → Sandbox 실행', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(_NoBootstrapAuthController.new),
        assessmentApiProvider.overrideWithValue(_FastCompleteAssessmentApi()),
        sandboxRunConnectProvider.overrideWithValue((_, _) => _logs(['OK'])),
      ],
    );
    addTearDown(container.dispose);

    // 1) 앱 시작 → 미인증 → 로그인
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const DevPathWebApp(),
      ),
    );
    await tester.pumpAndSettle();

    // 2) 목 로그인(PENDING) → 진단으로 게이트
    await tester.tap(find.text('GitHub로 계속하기 (목)'));
    await tester.pumpAndSettle();
    expect(find.byType(DiagnosticPage), findsOneWidget);

    // 3) 진단 시작 → 즉시 완료(next=null) → PATH 생성 화면
    await tester.tap(find.text('진단 시작하기'));
    await tester.pumpAndSettle();
    expect(find.byType(PathPage), findsOneWidget);

    // 4) 목 SSE(250ms×4) 완료까지 진행.
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Stream 구독 실습'), findsOneWidget); // 생성 완료된 이번 주 과제

    // 5) Sandbox 실행 → 실행 로그 수신(골든패스 마지막 구간).
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: DpTheme.light(), home: const SandboxPage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('실행'));
    await tester.pumpAndSettle();
    expect(find.textContaining('OK'), findsOneWidget);
  });
}
