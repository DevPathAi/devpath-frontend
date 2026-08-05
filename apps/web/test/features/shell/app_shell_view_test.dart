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

  // 계정 아이콘은 DpNavRail(다크 배경)과 DpChromeBar(밝은 배경, compact) 사이를
  // 오가는 같은 위젯 인스턴스다. Icon.color를 하드코딩하면 한쪽 배경에서
  // 대비가 무너진다 — 슬롯이 공급하는 IconTheme을 상속해야 한다.
  testWidgets('compact 폭: 계정 아이콘은 색을 상속하고 크롬바의 textSecondary가 된다', (
    tester,
  ) async {
    _setWidth(tester, 390);
    await tester.pumpWidget(
      _host(const AppShellView(location: '/dashboard', child: Text('본문'))),
    );

    final icon = tester.widget<Icon>(find.byIcon(DpIcons.account));
    expect(icon.color, isNull, reason: '하드코딩된 색이면 배경에 따라 상속받지 못해 대비가 무너진다');

    final context = tester.element(find.byIcon(DpIcons.account));
    expect(IconTheme.of(context).color, DpColors.light.textSecondary);
  });

  // I1 회귀 가드: kShellDestinations가 5→4로 줄면서 /settings가 목적지에서
  // 빠졌다. 예전 `_index`(매칭 실패 시 0 폴백)는 레일이 "대시보드"를 잘못
  // 활성 표시했다 — 크롬바 브레드크럼은 "계정 · 설정"이라 셸 안 두 위치
  // 표시가 서로 모순됐다. 지금은 매칭 실패 시 null(무강조)이어야 한다.
  testWidgets('/settings 위치에서 레일은 어떤 항목도 활성 표시하지 않는다(대시보드 오표시 회귀 방지)', (
    tester,
  ) async {
    _setWidth(tester, 1200);
    await tester.pumpWidget(
      _host(const AppShellView(location: '/settings', child: Text('본문'))),
    );
    final rail = tester.widget<DpNavRail>(find.byType(DpNavRail));
    expect(
      rail.selectedIndex,
      isNull,
      reason: '/settings는 kShellDestinations에 없다 — 0(대시보드)으로 폴백하면 잘못 강조된다',
    );
  });

  testWidgets('비-compact 폭: 계정 아이콘은 색을 상속하고 레일의 railMuted가 된다', (tester) async {
    _setWidth(tester, 1200);
    await tester.pumpWidget(
      _host(const AppShellView(location: '/dashboard', child: Text('본문'))),
    );

    final icon = tester.widget<Icon>(find.byIcon(DpIcons.account));
    expect(icon.color, isNull, reason: '하드코딩된 색이면 배경에 따라 상속받지 못해 대비가 무너진다');

    final context = tester.element(find.byIcon(DpIcons.account));
    expect(IconTheme.of(context).color, DpColors.light.railMuted);
  });

  // F1/F2 회귀 가드(2차 fix wave): DpTheme의 titleSmall은 이미 non-null
  // color(textPrimary)를 품고 있어(dp_theme.dart:32-34) Text.style에
  // color를 명시하지 않으면 DefaultTextStyle.merge에서 DpNavRail이 공급하는
  // railText를 이긴다. 라이트에서 textPrimary==railBg라 브랜드 텍스트가
  // 완전히 묻힌다 — Text 위젯의 "실효 색"(DefaultTextStyle과의 병합
  // 결과, Flutter Text가 실제로 렌더할 색)을 단언해 이 경로를 고정한다.
  Color? effectiveTextColor(WidgetTester tester, Finder finder) {
    final widget = tester.widget<Text>(finder);
    final context = tester.element(finder);
    final ambient = DefaultTextStyle.of(context).style;
    final effective = widget.style == null
        ? ambient
        : ambient.merge(widget.style);
    return effective.color;
  }

  testWidgets('레일 브랜드 텍스트의 실효 색은 라이트에서 railText다(레일 배경에 묻히지 않음)', (
    tester,
  ) async {
    _setWidth(tester, 1200);
    await tester.pumpWidget(
      _host(const AppShellView(location: '/dashboard', child: Text('본문'))),
    );

    final finder = find.descendant(
      of: find.byType(DpNavRail),
      matching: find.text('DevPath'),
    );
    expect(
      effectiveTextColor(tester, finder),
      DpColors.light.railText,
      reason:
          'titleSmall이 이미 textPrimary를 품고 있어 color를 명시하지 않으면 '
          'railText 대신 textPrimary로 렌더돼 라이트에서 railBg와 같은 색이 된다',
    );
  });

  testWidgets('레일 브랜드 텍스트의 실효 색은 다크에서도 railText다', (tester) async {
    _setWidth(tester, 1200);
    await tester.pumpWidget(
      MaterialApp(
        theme: DpTheme.dark(),
        home: const AppShellView(location: '/dashboard', child: Text('본문')),
      ),
    );

    final finder = find.descendant(
      of: find.byType(DpNavRail),
      matching: find.text('DevPath'),
    );
    expect(effectiveTextColor(tester, finder), DpColors.dark.railText);
  });
}
