import 'package:devpath_web/src/features/shell/presentation/app_shell.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// P4a-A: MediaQuery를 MaterialApp 바깥에 두면 MaterialApp의 MediaQuery.fromView가
// 가려 폭이 무시된다(기본 800×600). 반드시 tester.view.physicalSize로 설정한다.
Widget _host(Widget child) => MaterialApp(theme: DpTheme.light(), home: child);

void _setWidth(WidgetTester tester, double w) {
  tester.view.physicalSize = Size(w, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  test('첫 목적지 라벨은 Today다', () {
    expect(kWebNavItems.first.label, '오늘');
  });

  test('주 메뉴는 오늘·학습 경로·AI 멘토·커뮤니티(자식 3)다', () {
    expect(kWebNavItems.map((i) => i.label).toList(), [
      '오늘',
      '학습 경로',
      'AI 멘토',
      '커뮤니티',
    ]);
    expect(kWebNavItems.last.children.map((i) => i.label).toList(), [
      '자유게시판',
      'Q/A',
      '피드백',
    ]);
  });

  test('셸 위치 resolver는 canonical child만 Today로 묶고 legacy content는 중립이다', () {
    expect(shellDestinationIndexFor('/dashboard'), 0);
    expect(shellDestinationIndexFor('/path/301/today'), 0);
    expect(shellDestinationIndexFor('/mission/302/content/77'), 0);
    expect(shellDestinationIndexFor('/mission/302/sandbox'), 0);
    expect(shellDestinationIndexFor('/path'), 1);
    expect(shellDestinationIndexFor('/content/77'), isNull);
  });

  test('위치 → 헤더 선택 id', () {
    expect(webNavSelectedIdFor('/dashboard'), '/dashboard');
    expect(webNavSelectedIdFor('/path/301/today'), '/dashboard');
    expect(webNavSelectedIdFor('/mission/302/sandbox'), '/dashboard');
    expect(webNavSelectedIdFor('/path'), '/path');
    expect(webNavSelectedIdFor('/mentor'), '/mentor');
    expect(webNavSelectedIdFor('/community'), '/community?board=FREE');
    expect(webNavSelectedIdFor('/community?board=QNA'), '/community?board=QNA');
    expect(
      webNavSelectedIdFor('/community?board=FEEDBACK'),
      '/community?board=FEEDBACK',
    );
  });

  // Review Focus 3
  test('목적지에 없는 위치는 null 이다 — 헤더가 엉뚱한 항목에 밑줄을 긋지 않는다', () {
    for (final location in [
      '/settings',
      '/mypage',
      '/content/77',
      '/sandbox',
    ]) {
      expect(webNavSelectedIdFor(location), isNull, reason: location);
    }
  });

  testWidgets('모든 폭에서 상단 헤더 셸이다 — 레일도 하단 내비도 없다', (tester) async {
    for (final width in [390.0, 700.0, 1400.0]) {
      _setWidth(tester, width);
      await tester.pumpWidget(
        _host(const AppShellView(location: '/dashboard', child: Text('본문'))),
      );
      expect(find.byType(DpWebShell), findsOneWidget, reason: '폭 $width');
      expect(find.byType(DpNavRail), findsNothing, reason: '폭 $width');
      expect(find.byType(DpMobileNavigation), findsNothing, reason: '폭 $width');
    }
  });

  testWidgets('헤더에서 목적지를 고르면 해당 경로로 콜백', (tester) async {
    _setWidth(tester, 1400);
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
    await tester.pumpAndSettle();
    expect(picked, '/mentor');
  });

  testWidgets('390 폭: 햄버거 메뉴 안에서 게시판으로 이동한다', (tester) async {
    _setWidth(tester, 390);
    String? picked;
    await tester.pumpWidget(
      _host(
        AppShellView(
          location: '/community',
          onSelect: (p) => picked = p,
          child: const Text('본문'),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('web-header-burger')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('피드백'));
    await tester.pumpAndSettle();
    expect(picked, '/community?board=FEEDBACK');
  });

  testWidgets('계정 메뉴에서 로그아웃을 실행할 수 있다', (tester) async {
    _setWidth(tester, 1400);
    var logoutCalls = 0;
    await tester.pumpWidget(
      _host(
        AppShellView(
          location: '/dashboard',
          onLogout: () async => logoutCalls++,
          child: const Text('본문'),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('web-header-account')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('로그아웃'));
    await tester.pump();
    expect(logoutCalls, 1);
  });

  testWidgets('푸터 링크: 약관·처리방침은 외부로, 오류 신고는 앱 안에서 연다', (tester) async {
    _setWidth(tester, 1400);
    final opened = <String>[];
    var supportCalls = 0;
    await tester.pumpWidget(
      _host(
        AppShellView(
          location: '/dashboard',
          onOpenExternal: opened.add,
          onOpenSupport: () => supportCalls++,
          child: const Text('본문'),
        ),
      ),
    );

    await tester.tap(find.text('이용약관'));
    await tester.tap(find.text('개인정보 처리방침'));
    await tester.tap(find.text('업데이트 소식'));
    await tester.tap(find.text('오류 신고·문의'));
    await tester.pump();

    expect(opened, [
      'https://leva.ai.kr/terms',
      'https://leva.ai.kr/privacy',
      'https://leva.ai.kr/updates',
    ]);
    expect(supportCalls, 1);
  });

  testWidgets('계정 아이콘은 색을 하드코딩하지 않고 어두운 헤더가 공급하는 색을 받는다', (tester) async {
    _setWidth(tester, 1400);
    await tester.pumpWidget(
      _host(const AppShellView(location: '/dashboard', child: Text('본문'))),
    );

    final icon = tester.widget<Icon>(find.byIcon(DpIcons.account));
    expect(icon.color, isNull, reason: '하드코딩된 색이면 배경에 따라 상속받지 못해 대비가 무너진다');
  });

  // 순수 함수(breadcrumbFor) 테스트만으로는 배선이 끊겨도 통과한다 — 셸이 실제로
  // 브레드크럼을 본문 위에 놓는지, 세그먼트 탭이 콜백을 트리거하는지 확인한다.
  testWidgets('게시글 상세 위치는 본문 상단에 3세그먼트 브레드크럼이 배선된다', (tester) async {
    _setWidth(tester, 1400);
    await tester.pumpWidget(
      _host(
        const AppShellView(
          location: '/community/post/12?board=FREE',
          child: Text('본문'),
        ),
      ),
    );

    final crumb = tester.widget<DpBreadcrumb>(find.byType(DpBreadcrumb));
    expect(crumb.crumbs, const [
      (label: '커뮤니티', path: null),
      (label: '자유게시판', path: '/community?board=FREE'),
      (label: '게시글', path: null),
    ]);
  });

  testWidgets('브레드크럼의 클릭 가능 세그먼트를 탭하면 해당 경로로 콜백', (tester) async {
    _setWidth(tester, 1400);
    String? picked;
    await tester.pumpWidget(
      _host(
        AppShellView(
          location: '/community/post/12?board=FREE',
          onSelect: (p) => picked = p,
          child: const Text('본문'),
        ),
      ),
    );

    // 헤더 드롭다운 항목 라벨도 "자유게시판"이라 브레드크럼 안으로 범위를 좁힌다.
    await tester.tap(
      find.descendant(
        of: find.byType(DpBreadcrumb),
        matching: find.text('자유게시판'),
      ),
    );
    expect(picked, '/community?board=FREE');
  });

  // I1 회귀 가드: /settings 는 목적지에 없다. 예전 레일은 매칭 실패 시 0(대시보드)으로
  // 폴백해 잘못된 항목을 활성 표시했다 — 헤더도 같은 실수를 하면 안 된다.
  testWidgets('/settings 위치에서 헤더는 어떤 항목도 활성 표시하지 않는다', (tester) async {
    _setWidth(tester, 1400);
    await tester.pumpWidget(
      _host(const AppShellView(location: '/settings', child: Text('본문'))),
    );
    final header = tester.widget<DpWebHeader>(find.byType(DpWebHeader));
    expect(
      header.selectedId,
      isNull,
      reason: '/settings는 kWebNavItems에 없다 — 폴백하면 잘못 강조된다',
    );
  });

  testWidgets('canonical mission child는 헤더에서 Today를 선택한다', (tester) async {
    _setWidth(tester, 1400);
    await tester.pumpWidget(
      _host(
        const AppShellView(
          location: '/mission/302/content/77',
          child: Text('본문'),
        ),
      ),
    );

    final header = tester.widget<DpWebHeader>(find.byType(DpWebHeader));
    expect(header.selectedId, '/dashboard');
  });

  // 3단계(DpRailBrand)부터 앱은 Text를 직접 만들지 않는다 — brand: 에 DpRailBrand 를
  // 넘기면 워드마크 Text 는 셸 위젯 내부에서 색을 명시해 만들어진다. 여기서는 web 셸이
  // 실제로 그 경로를 쓰는지(raw Text 회귀가 없는지)를 앱 레벨에서 고정한다.
  Color? effectiveTextColor(WidgetTester tester, Finder finder) {
    final widget = tester.widget<Text>(finder);
    final context = tester.element(finder);
    final ambient = DefaultTextStyle.of(context).style;
    final effective = widget.style == null
        ? ambient
        : ambient.merge(widget.style);
    return effective.color;
  }

  testWidgets('헤더 브랜드 텍스트의 실효 색은 라이트에서 headerText다', (tester) async {
    _setWidth(tester, 1400);
    await tester.pumpWidget(
      _host(const AppShellView(location: '/dashboard', child: Text('본문'))),
    );

    final finder = find.descendant(
      of: find.byType(DpWebHeader),
      matching: find.text('Leva'),
    );
    expect(
      effectiveTextColor(tester, finder),
      DpColors.light.headerText,
      reason: 'titleMedium이 textPrimary를 품고 있어 명시하지 않으면 headerBg와 같은 색이 된다',
    );
  });

  testWidgets('헤더 브랜드 텍스트의 실효 색은 다크에서도 headerText다', (tester) async {
    _setWidth(tester, 1400);
    await tester.pumpWidget(
      MaterialApp(
        theme: DpTheme.dark(),
        home: const AppShellView(location: '/dashboard', child: Text('본문')),
      ),
    );

    final finder = find.descendant(
      of: find.byType(DpWebHeader),
      matching: find.text('Leva'),
    );
    expect(effectiveTextColor(tester, finder), DpColors.dark.headerText);
  });
}
