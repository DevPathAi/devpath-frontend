import 'package:devpath_admin/src/features/auth/application/auth_controller.dart';
import 'package:devpath_admin/src/features/auth/presentation/auth_callback_page.dart';
import 'package:devpath_admin/src/features/auth/presentation/forbidden_page.dart';
import 'package:devpath_admin/src/features/auth/presentation/login_page.dart';
import 'package:devpath_admin/src/features/auth/state/auth_state.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Auth extends AdminAuthController {
  _Auth(this.initial);

  final AdminAuthState initial;

  @override
  AdminAuthState build() => initial;

  @override
  Future<void> bootstrapFromCallback() async {}

  @override
  Future<void> logout() async {}
}

Widget _app(Widget home, AdminAuthState state) => ProviderScope(
  overrides: [adminAuthProvider.overrideWith(() => _Auth(state))],
  child: MaterialApp(theme: DpTheme.light(), home: home),
);

void main() {
  testWidgets('login exposes shared wordmark, heading and live error', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(const AdminLoginPage(), const AdminUnauthed(error: '인증 실패')),
    );

    expect(find.text('Leva'), findsOneWidget);
    expect(find.text('운영 콘솔'), findsOneWidget);
    expect(find.text('관리자 로그인'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.header == true &&
            widget.properties.label == '관리자 로그인',
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.liveRegion == true &&
            widget.properties.label == '로그인 실패: 인증 실패',
      ),
      findsOneWidget,
    );
  });

  testWidgets('callback and forbidden use the same accessible access frame', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(const AdminAuthCallbackPage(), const AdminUnauthed()),
    );
    await tester.pump();

    expect(find.text('Leva'), findsOneWidget);
    expect(find.text('관리자 세션 확인 중'), findsOneWidget);
    expect(find.byType(DpLoading), findsOneWidget);

    await tester.pumpWidget(
      _app(const AdminForbiddenPage(), const AdminUnauthed()),
    );
    await tester.pump();

    expect(find.text('Leva'), findsOneWidget);
    expect(find.text('이 계정으로는 접근할 수 없어요'), findsOneWidget);
    expect(find.text('다른 계정으로 로그인'), findsOneWidget);
  });

  testWidgets('access frame reflows at 320/200%', (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminAuthProvider.overrideWith(() => _Auth(const AdminUnauthed())),
        ],
        child: MaterialApp(
          theme: DpTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: const AdminLoginPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('관리자 로그인'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
