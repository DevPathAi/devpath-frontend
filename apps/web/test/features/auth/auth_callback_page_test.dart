import 'package:devpath_web/src/features/auth/application/auth_controller.dart';
import 'package:devpath_web/src/features/auth/presentation/auth_callback_page.dart';
import 'package:devpath_web/src/features/auth/state/auth_state.dart';
import 'package:devpath_web/src/features/diagnostic/application/diagnostic_controller.dart';
import 'package:devpath_web/src/features/diagnostic/state/diagnostic_continuation.dart';
import 'package:devpath_web/src/features/diagnostic/state/diagnostic_state.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _CallbackAuthController extends AuthController {
  _CallbackAuthController({this.error = 'OAuth callback failed'});

  final String? error;
  int bootstrapCalls = 0;

  @override
  AuthState build() => AuthUnauthenticated(error: error);

  @override
  Future<void> bootstrapFromCallback() async => bootstrapCalls++;
}

class _ContinuationController extends DiagnosticController {
  String? oauthFailure;

  @override
  DiagnosticState build() => const DiagnosticState(
    phase: DiagnosticContinuationPhase.auth,
    track: 'BACKEND_SPRING',
    guestId: '123e4567-e89b-42d3-a456-426614174000',
    preview: AssessmentResult(diagnosedLevel: 'MID', confidenceWeight: 0.8),
  );

  @override
  void markOAuthFailure(String message) => oauthFailure = message;
}

void main() {
  testWidgets('OAuth 실패는 spinner 대신 retry와 보존된 preview 복귀를 제공한다', (
    tester,
  ) async {
    final auth = _CallbackAuthController();
    final continuation = _ContinuationController();
    final router = GoRouter(
      initialLocation: '/auth/callback',
      routes: [
        GoRoute(
          path: '/auth/callback',
          builder: (_, _) => const AuthCallbackPage(),
        ),
        GoRoute(path: '/diagnostic', builder: (_, _) => const Text('PREVIEW')),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(() => auth),
          diagnosticControllerProvider.overrideWith(() => continuation),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('로그인을 완료하지 못했어요'), findsOneWidget);
    expect(find.text('로그인 다시 확인'), findsOneWidget);
    expect(find.text('진단 결과로 돌아가기'), findsOneWidget);
    expect(continuation.oauthFailure, isNotNull);

    await tester.tap(find.text('로그인 다시 확인'));
    expect(auth.bootstrapCalls, greaterThanOrEqualTo(2));

    await tester.tap(find.text('진단 결과로 돌아가기'));
    await tester.pumpAndSettle();
    expect(find.text('PREVIEW'), findsOneWidget);
  });

  testWidgets('오류 문구가 없는 미인증 callback도 generic 복구 UI로 종결한다', (tester) async {
    final auth = _CallbackAuthController(error: null);
    final continuation = _ContinuationController();
    final router = GoRouter(
      initialLocation: '/auth/callback',
      routes: [
        GoRoute(
          path: '/auth/callback',
          builder: (_, _) => const AuthCallbackPage(),
        ),
        GoRoute(path: '/diagnostic', builder: (_, _) => const Text('PREVIEW')),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(() => auth),
          diagnosticControllerProvider.overrideWith(() => continuation),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('로그인을 완료하지 못했어요'), findsOneWidget);
    expect(find.text('로그인 상태를 확인하지 못했어요. 다시 시도해 주세요.'), findsOneWidget);
    expect(find.text('로그인 다시 확인'), findsOneWidget);
    expect(find.text('진단 결과로 돌아가기'), findsOneWidget);
    expect(continuation.oauthFailure, isNotNull);
  });
}
