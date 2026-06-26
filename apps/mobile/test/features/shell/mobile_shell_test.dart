import 'package:devpath_mobile/src/features/shell/presentation/mobile_shell.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

GoRouter _testRouter() => GoRouter(
  initialLocation: '/a',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (_, _, shell) => MobileShell(navigationShell: shell),
      branches: [
        StatefulShellBranch(
          routes: [GoRoute(path: '/a', builder: (_, _) => const Text('A화면'))],
        ),
        StatefulShellBranch(
          routes: [GoRoute(path: '/b', builder: (_, _) => const Text('B화면'))],
        ),
        StatefulShellBranch(
          routes: [GoRoute(path: '/c', builder: (_, _) => const Text('C화면'))],
        ),
      ],
    ),
  ],
);

void main() {
  testWidgets('하단 NavigationBar 3탭 렌더 + 탭 전환', (tester) async {
    await tester.pumpWidget(
      MaterialApp.router(theme: DpTheme.light(), routerConfig: _testRouter()),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('홈'), findsOneWidget);
    expect(find.text('학습'), findsOneWidget);
    expect(find.text('커뮤니티'), findsOneWidget);
    expect(find.text('A화면'), findsOneWidget);

    await tester.tap(find.text('학습'));
    await tester.pumpAndSettle();
    expect(find.text('B화면'), findsOneWidget);
  });
}
