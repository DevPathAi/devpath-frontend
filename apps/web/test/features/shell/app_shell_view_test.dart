import 'package:devpath_web/src/features/shell/presentation/app_shell.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// P4a-A: MediaQuery를 MaterialApp 바깥에 두면 MaterialApp의 MediaQuery.fromView가
// 가려 폭이 무시된다(기본 800×600). 반드시 tester.view.physicalSize로 설정한다.
Widget _host(Widget child) => MaterialApp(theme: DpTheme.light(), home: child);

void _setWidth(WidgetTester tester, double w) {
  tester.view.physicalSize = Size(w, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('좁은 폭(<840)은 NavigationBar', (tester) async {
    _setWidth(tester, 390);
    await tester.pumpWidget(
      _host(const AppShellView(location: '/dashboard', child: Text('본문'))),
    );
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(DpNavRail), findsNothing);
  });

  testWidgets('넓은 폭(≥840)은 DpNavRail', (tester) async {
    _setWidth(tester, 1200);
    await tester.pumpWidget(
      _host(const AppShellView(location: '/dashboard', child: Text('본문'))),
    );
    expect(find.byType(DpNavRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('목적지 선택 시 해당 경로로 콜백', (tester) async {
    _setWidth(tester, 390);
    String? picked;
    await tester.pumpWidget(
      _host(
        AppShellView(
          location: '/dashboard',
          onSelect: (p) => picked = p,
          child: const Text('본문'),
        ),
      ),
    );
    await tester.tap(find.text('AI 멘토'));
    expect(picked, '/mentor');
  });

  testWidgets('중간 폭(600–839)은 접힌 NavigationRail(하단 Bar 아님)', (tester) async {
    _setWidth(tester, 700);
    await tester.pumpWidget(
      _host(const AppShellView(location: '/dashboard', child: Text('본문'))),
    );
    expect(find.byType(DpNavRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    final rail = tester.widget<DpNavRail>(find.byType(DpNavRail));
    expect(rail.extended, isFalse);
  });

  testWidgets('Large 폭(≥1240)은 펼친 Rail + 본문 최대폭 제약', (tester) async {
    _setWidth(tester, 1400);
    await tester.pumpWidget(
      _host(const AppShellView(location: '/dashboard', child: Text('본문'))),
    );
    final rail = tester.widget<DpNavRail>(find.byType(DpNavRail));
    expect(rail.extended, isTrue);
    expect(find.byType(DpMaxWidth), findsOneWidget);
  });

  // 순수 함수(breadcrumbFor) 테스트만으로는 배선이 끊겨도 통과한다 — 셸이
  // 실제로 크롬바에 전달하는지, 세그먼트 탭이 실제로 콜백을 트리거하는지
  // 위젯 테스트로 확인한다.
  testWidgets('게시글 상세 위치는 크롬바에 3세그먼트 브레드크럼이 배선된다', (tester) async {
    _setWidth(tester, 1200);
    await tester.pumpWidget(
      _host(
        const AppShellView(location: '/community/post/12', child: Text('본문')),
      ),
    );

    final chromeBar = tester.widget<DpChromeBar>(find.byType(DpChromeBar));
    expect(chromeBar.breadcrumb, const [
      (label: '커뮤니티', path: null),
      (label: '게시판', path: '/community'),
      (label: '게시글', path: null),
    ]);
  });

  testWidgets('브레드크럼의 클릭 가능 세그먼트를 탭하면 해당 경로로 콜백', (tester) async {
    _setWidth(tester, 1200);
    String? picked;
    await tester.pumpWidget(
      _host(
        AppShellView(
          location: '/community/post/12',
          onSelect: (p) => picked = p,
          child: const Text('본문'),
        ),
      ),
    );

    // 레일 목적지 라벨도 "게시판"이라 크롬바 안으로 범위를 좁힌다.
    await tester.tap(
      find.descendant(of: find.byType(DpChromeBar), matching: find.text('게시판')),
    );
    expect(picked, '/community');
  });
}
