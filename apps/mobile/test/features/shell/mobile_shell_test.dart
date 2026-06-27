import 'dart:async';

import 'package:devpath_mobile/src/features/shell/presentation/mobile_shell.dart';
import 'package:devpath_mobile/src/services/push_service.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _FakePush implements PushService {
  _FakePush(this._controller);

  final StreamController<PushMessage> _controller;

  @override
  Future<String?> getToken() async => 'fake-token';

  @override
  Stream<PushMessage> get incoming => _controller.stream;
}

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
        StatefulShellBranch(
          routes: [GoRoute(path: '/d', builder: (_, _) => const Text('D화면'))],
        ),
      ],
    ),
  ],
);

Widget _host(GoRouter router, {PushService? push}) => ProviderScope(
  overrides: [pushServiceProvider.overrideWithValue(push ?? StubPushService())],
  child: MaterialApp.router(theme: DpTheme.light(), routerConfig: router),
);

void main() {
  testWidgets('하단 NavigationBar 4탭 렌더 + 탭 전환', (tester) async {
    await tester.pumpWidget(_host(_testRouter()));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('홈'), findsOneWidget);
    expect(find.text('학습'), findsOneWidget);
    expect(find.text('커뮤니티'), findsOneWidget);
    expect(find.text('알림'), findsOneWidget);
    expect(find.text('A화면'), findsOneWidget);

    await tester.tap(find.text('학습'));
    await tester.pumpAndSettle();
    expect(find.text('B화면'), findsOneWidget);

    await tester.tap(find.text('알림'));
    await tester.pumpAndSettle();
    expect(find.text('D화면'), findsOneWidget);
  });

  testWidgets('미읽음 없으면 배지 숨김', (tester) async {
    await tester.pumpWidget(_host(_testRouter()));
    await tester.pumpAndSettle();

    // 스텁 푸시(수신 없음) → 미읽음 0 → 배지 라벨 없음.
    expect(find.text('1'), findsNothing);
  });

  testWidgets('미읽음 있으면 알림 탭에 배지(개수) 표시', (tester) async {
    final ctrl = StreamController<PushMessage>();
    addTearDown(ctrl.close);
    // 셸이 컨트롤러를 watch → 구독 시점에 버퍼된 수신이 전달되어 미읽음 1.
    ctrl.add(const PushMessage(id: '1', title: '새 알림', body: '본문'));

    await tester.pumpWidget(_host(_testRouter(), push: _FakePush(ctrl)));
    await tester.pumpAndSettle();

    expect(find.text('1'), findsOneWidget);
  });
}
