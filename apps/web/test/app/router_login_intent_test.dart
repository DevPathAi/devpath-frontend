import 'package:devpath_web/src/app/app_config.dart';
import 'package:devpath_web/src/app/router.dart';
import 'package:devpath_web/src/features/auth/application/auth_controller.dart';
import 'package:devpath_web/src/features/auth/state/auth_state.dart';
import 'package:devpath_web/src/providers/api_providers.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _UnauthController extends AuthController {
  @override
  AuthState build() => const AuthUnauthenticated();
}

/// 랜딩의 「AI 멘토 초대 신청」은 `/login?intent=invite` 로 온다(점검 A-1).
/// 쿼리가 게이트 redirect 를 거쳐 로그인 화면까지 살아 있어야 문구가 바뀐다.
Future<void> _pumpAt(WidgetTester tester, String location) async {
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: [
      appConfigProvider.overrideWithValue(
        const AppConfig(
          baseUrl: 'https://test.devpath.ai/api/v1',
          useMock: false,
        ),
      ),
      authControllerProvider.overrideWith(_UnauthController.new),
    ],
  );
  addTearDown(container.dispose);
  final router = container.read(routerProvider);
  router.go(location);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(theme: DpTheme.light(), routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('/login?intent=invite 는 초대 신청 문구로 연다', (tester) async {
    await _pumpAt(tester, '/login?intent=invite');

    expect(find.text('AI 멘토 초대 신청'), findsOneWidget);
  });

  testWidgets('/login 은 기본 로그인 문구로 연다', (tester) async {
    await _pumpAt(tester, '/login');

    expect(find.text('로그인'), findsOneWidget);
    expect(find.text('AI 멘토 초대 신청'), findsNothing);
  });
}
