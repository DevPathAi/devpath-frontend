import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void _setWidth(WidgetTester tester, double w) {
  tester.view.physicalSize = Size(w, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Widget _host({List<DpCrumb> breadcrumb = const []}) => MaterialApp(
  theme: DpTheme.light(),
  home: DpWebShell(
    brand: DpRailBrand(mark: const DpBrandMark(size: 24), wordmark: 'Leva'),
    items: const [DpWebNavItem(id: '/dashboard', label: '오늘')],
    selectedId: '/dashboard',
    onSelect: (_) {},
    accountEntries: [(label: '로그아웃', onSelect: () {})],
    footerNotice: '© 레바',
    footerLinks: [(label: '이용약관', onTap: () {})],
    breadcrumb: breadcrumb,
    body: const Text('본문'),
  ),
);

void main() {
  testWidgets('헤더 · 본문 · 푸터를 세로로 쌓는다 — 레일과 하단 내비는 없다', (tester) async {
    _setWidth(tester, 1240);
    await tester.pumpWidget(_host());

    expect(find.byType(DpWebHeader), findsOneWidget);
    expect(find.text('본문'), findsOneWidget);
    expect(find.byType(DpWebFooter), findsOneWidget);
    expect(find.byType(DpNavRail), findsNothing);
    expect(find.byType(DpMobileNavigation), findsNothing);
    expect(find.byType(DpChromeBar), findsNothing);
  });

  testWidgets('푸터는 헤더보다 아래, 본문보다 아래다', (tester) async {
    _setWidth(tester, 1240);
    await tester.pumpWidget(_host());

    final header = tester.getRect(find.byType(DpWebHeader));
    final footer = tester.getRect(find.byType(DpWebFooter));
    expect(footer.top, greaterThan(header.bottom));
  });

  testWidgets('compact 에서도 푸터는 보인다(사용자 결정: 셸 하단 고정)', (tester) async {
    _setWidth(tester, 390);
    await tester.pumpWidget(_host());
    expect(find.byType(DpWebFooter), findsOneWidget);
  });

  testWidgets('본문은 contentMaxWidth 로 중앙 정렬된다 — large 뿐 아니라 모든 폭에서', (
    tester,
  ) async {
    for (final width in [900.0, 1600.0]) {
      _setWidth(tester, width);
      await tester.pumpWidget(_host());
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('web-shell-main')),
          matching: find.byType(DpMaxWidth),
        ),
        findsOneWidget,
        reason:
            '폭 $width 에서 본문 최대폭 제약이 없다 — 시안의 .main{max-width:1120px} 은 무조건이다',
      );
    }
  });

  testWidgets('브레드크럼은 본문 위, 헤더 아래에 놓인다', (tester) async {
    _setWidth(tester, 1240);
    await tester.pumpWidget(
      _host(
        breadcrumb: const [
          (label: '커뮤니티', path: '/community'),
          (label: 'Q/A', path: null),
        ],
      ),
    );

    final crumb = tester.getRect(find.byType(DpBreadcrumb));
    final header = tester.getRect(find.byType(DpWebHeader));
    final body = tester.getRect(find.text('본문'));
    expect(crumb.top, greaterThanOrEqualTo(header.bottom));
    expect(crumb.bottom, lessThanOrEqualTo(body.top));
  });

  testWidgets('브레드크럼이 비면 자리를 차지하지 않는다', (tester) async {
    _setWidth(tester, 1240);
    await tester.pumpWidget(_host());
    expect(find.byType(DpBreadcrumb), findsOneWidget);
    expect(tester.getSize(find.byType(DpBreadcrumb)).height, 0);
  });

  // 리뷰 실측(2026-09-26): 720 compact 경계 바로 위 구간에서 헤더가 가로로 넘쳤다
  // (720 → 67px, 740 → 47px, 768 → 19px). Flex.clipBehavior 기본값이 Clip.none 이라
  // 커뮤니티 드롭다운이 검색 상자 위에 겹쳐 그려진다. browser-ux 는 RenderFlex
  // 오버플로가 scrollWidth 를 키우지 않아 못 잡는다.
  testWidgets('compact 경계 바로 위(720~839)에서 헤더가 넘치지 않는다', (tester) async {
    for (final width in [720.0, 740.0, 768.0, 800.0, 839.0]) {
      _setWidth(tester, width);
      await tester.pumpWidget(_hostFullNav());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '폭 $width 에서 헤더가 넘쳤다');
    }
  });

  // 리뷰 실측(2026-09-26): 짧은 화면에서 접힘 메뉴를 열면 Expanded 가 0 으로 눌리고
  // 아래가 잘려 계정 항목(마이페이지·설정·로그아웃)에 도달할 수 없었다
  // (667x375 → 191px, 390x844 200% → 121px 오버플로).
  testWidgets('짧은 화면에서 접힘 메뉴를 열어도 잘리지 않는다', (tester) async {
    for (final size in [const Size(667, 375), const Size(390, 500)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // 같은 위젯 타입을 다시 pump 하면 State 가 살아남아 _expanded 가 이월된다
      // → 다음 탭이 메뉴를 '닫는다'. 크기마다 셸을 새로 만든다.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(_hostFullNav());
      await tester.tap(find.byKey(const ValueKey('web-header-burger')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: '$size 에서 접힘 메뉴가 넘쳤다');
      expect(
        find.text('로그아웃'),
        findsOneWidget,
        reason: '$size 에서 계정 항목이 트리에서 사라졌다',
      );
    }
  });

  // ⚠ 이 테스트는 **브라우저를 보장하지 않는다.** VM 에서는 통과하는데 Flutter Web
  // 에서는 헤더가 시맨틱스 트리에 아예 없다(로컬 실측 2026-09-26, 아래 기록).
  //   · 헤더는 그려진다(스크린샷 확인) — 마우스로는 눌린다
  //   · 시맨틱스 노드는 0개 — 보조기술·Playwright 는 닿지 못한다
  //   · 위치·위젯 종류·활성화 타이밍·FocusTraversalGroup 전부 배제(실험 6회)
  //   · 규칙: 각 Column 에서 **Expanded 앞에 오는 형제**만 빠진다. 헤더와
  //     본문 Column 에 끼워 본 프로브 버튼 4종이 모두 빠졌고, Expanded 와
  //     그 뒤(푸터)는 남는다
  // 재현: apps/web 을 mock 릴리스로 빌드 → 핀 Playwright 이미지에서
  // flt-semantics 노드를 덤프. 절차는 PR #233 설명과 실행 원장에 있다.
  testWidgets('390: 셸 전체에서도 햄버거와 브랜드가 시맨틱스에 있다(VM 한정)', (tester) async {
    final handle = tester.ensureSemantics();

    _setWidth(tester, 390);
    await tester.pumpWidget(_hostFullNav());
    await tester.pumpAndSettle();

    expect(
      tester
          .getSemantics(find.byKey(const ValueKey('web-header-burger')))
          .label,
      '메뉴',
    );
    expect(find.bySemanticsLabel('Leva'), findsWidgets);
    handle.dispose();
  });
}

Widget _hostFullNav() => MaterialApp(
  theme: DpTheme.light(),
  home: DpWebShell(
    brand: DpRailBrand(mark: const DpBrandMark(size: 24), wordmark: 'Leva'),
    items: const [
      DpWebNavItem(id: '/dashboard', label: '오늘'),
      DpWebNavItem(id: '/path', label: '학습 경로'),
      DpWebNavItem(id: '/mentor', label: 'AI 멘토'),
      DpWebNavItem(
        id: '/community',
        label: '커뮤니티',
        children: [
          DpWebNavItem(id: '/community?board=FREE', label: '자유게시판'),
          DpWebNavItem(id: '/community?board=QNA', label: 'Q/A'),
          DpWebNavItem(id: '/community?board=FEEDBACK', label: '피드백'),
        ],
      ),
    ],
    selectedId: '/dashboard',
    onSelect: (_) {},
    accountEntries: [
      (label: '마이페이지', onSelect: () {}),
      (label: '설정', onSelect: () {}),
      (label: '로그아웃', onSelect: () {}),
    ],
    footerNotice: '© 레바 · 사업자등록번호 796-76-00732',
    footerLinks: [
      (label: '이용약관', onTap: () {}),
      (label: '개인정보 처리방침', onTap: () {}),
      (label: '오류 신고·문의', onTap: () {}),
      (label: '업데이트 소식', onTap: () {}),
    ],
    onSearchTap: () {},
    body: const Text('본문'),
  ),
);
