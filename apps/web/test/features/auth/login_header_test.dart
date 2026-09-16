import 'package:devpath_web/src/features/auth/application/auth_controller.dart';
import 'package:devpath_web/src/features/auth/presentation/login_page.dart';
import 'package:devpath_web/src/features/auth/state/auth_state.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _NoBootstrapAuthController extends AuthController {
  @override
  AuthState build() => const AuthUnauthenticated();
}

Widget _host() => ProviderScope(
  overrides: [
    authControllerProvider.overrideWith(_NoBootstrapAuthController.new),
  ],
  child: MaterialApp(theme: DpTheme.light(), home: const LoginPage()),
);

void main() {
  testWidgets('로그인은 AppBar 없이 헤더 + 테마 전환 버튼을 유지', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(AppBar), findsNothing);
    final header = tester.widget<DpPageHeader>(find.byType(DpPageHeader));
    expect(header.title, '다시 만나서 반가워요');
    expect(find.byTooltip('테마 전환'), findsOneWidget);
    // T3: brandRow(context) 호출 자체를 지워도 byTooltip 단언은 깨지지 않는다
    // (버튼이 brandRow 밖으로 옮겨져도 통과한다) — brandRow의 key로 호출
    // 자체를 직접 단언한다(find.text보다 brandRow 위젯 유무에 견고하다 —
    // F4, 4화면 전부 이 형태로 통일).
    expect(find.byKey(const ValueKey('brand-row')), findsOneWidget);
    expect(find.text('Leva'), findsOneWidget);
  });

  testWidgets('desktop login uses a split story and access layout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host());
    await tester.pump();

    expect(find.byKey(const ValueKey('login-story-panel')), findsOneWidget);
    expect(find.byKey(const ValueKey('login-access-panel')), findsOneWidget);
    expect(find.text('오늘 할 일을 선명하게,'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('다시 만나서 반가워요')).dx,
      closeTo(tester.getTopLeft(find.byType(FilledButton)).dx, 0.1),
    );
  });

  testWidgets(
    'mobile login removes the story panel and keeps one focused flow',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_host());
      await tester.pump();

      expect(find.byKey(const ValueKey('login-story-panel')), findsNothing);
      expect(find.byKey(const ValueKey('login-access-panel')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
