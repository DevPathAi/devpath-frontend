import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _items = [
  DpWebNavItem(id: '/dashboard', label: '오늘'),
  DpWebNavItem(id: '/path', label: '학습 경로'),
  DpWebNavItem(
    id: '/community',
    label: '커뮤니티',
    children: [
      DpWebNavItem(id: '/community?board=FREE', label: '자유게시판'),
      DpWebNavItem(id: '/community?board=QNA', label: 'Q/A'),
    ],
  ),
];

void _setWidth(WidgetTester tester, double w) {
  tester.view.physicalSize = Size(w, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Widget _host({
  String? selectedId,
  void Function(String)? onSelect,
  double? textScale,
}) => MaterialApp(
  theme: DpTheme.light(),
  builder: (context, child) => textScale == null
      ? child!
      : MediaQuery.withClampedTextScaling(
          minScaleFactor: textScale,
          maxScaleFactor: textScale,
          child: child!,
        ),
  home: Scaffold(
    body: DpWebHeader(
      brand: DpRailBrand(mark: const DpBrandMark(size: 24), wordmark: 'Leva'),
      items: _items,
      selectedId: selectedId,
      onSelect: onSelect ?? (_) {},
      accountEntries: [
        (label: '마이페이지', onSelect: () {}),
        (label: '설정', onSelect: () {}),
        (label: '로그아웃', onSelect: () {}),
      ],
      onSearchTap: () {},
    ),
  ),
);

void main() {
  testWidgets('넓은 폭: 주 메뉴가 보이고 햄버거는 없다', (tester) async {
    _setWidth(tester, 1240);
    await tester.pumpWidget(_host());

    expect(find.text('오늘'), findsOneWidget);
    expect(find.text('학습 경로'), findsOneWidget);
    expect(find.text('커뮤니티'), findsOneWidget);
    expect(find.byKey(const ValueKey('web-header-burger')), findsNothing);
  });

  // 좌우 정렬 계약(2026-10-01 사용자 지적). 1920 폭 실화면에서 주 메뉴 항목이
  // 헤더 전체로 흩어지고(항목마다 균등 몫을 통째로 차지) 검색·계정 오른쪽에는
  // 빈 띠가 남아 있었다. 계약은 둘뿐이다 — **브랜드+주 메뉴는 왼쪽에 모이고,
  // 검색+계정은 오른쪽 끝에 붙는다.** 간격은 전부 토큰 산술로 못박는다.
  testWidgets('넓은 폭: 브랜드·주 메뉴는 왼쪽에 모이고 검색·계정은 오른쪽 끝에 붙는다', (tester) async {
    _setWidth(tester, 1920);
    await tester.pumpWidget(_host(selectedId: '/dashboard'));

    final bar = tester.getRect(find.byKey(const ValueKey('web-header-bar')));
    final brand = tester.getRect(find.text('Leva'));
    final today = tester.getRect(find.text('오늘'));
    final path = tester.getRect(find.text('학습 경로'));
    final community = tester.getRect(find.text('커뮤니티'));

    // 브랜드 → 첫 항목: 그룹 간격(xl) + 항목 좌측 패딩(md).
    expect(
      today.left - brand.right,
      closeTo(DpSpacing.xl + DpSpacing.md, 1),
      reason: '주 메뉴가 브랜드에 이어 붙지 않고 멀어졌다',
    );

    // 항목 사이: 앞 항목 우측 패딩(md) + 항목 간격(xs) + 뒤 항목 좌측 패딩(md).
    const navGap = DpSpacing.md * 2 + DpSpacing.xs;
    expect(
      path.left - today.right,
      closeTo(navGap, 1),
      reason: '주 메뉴 항목이 남는 폭을 나눠 가지며 흩어졌다',
    );
    expect(community.left - path.right, closeTo(navGap, 1));

    // 현재 항목 밑줄은 라벨 폭 + 좌우 패딩이다 — 균등 몫 전체가 아니다.
    expect(
      tester
          .getRect(find.byKey(const ValueKey('web-header-current-/dashboard')))
          .width,
      closeTo(today.width + DpSpacing.md * 2, 1),
      reason: '밑줄이 라벨이 아니라 항목이 차지한 폭 전체에 그려졌다',
    );

    // 우측 그룹은 바의 수평 패딩(xl)에 붙는다 — 남는 폭은 전부 주 메뉴 쪽이
    // 흡수해야 한다(Row 끝에 남으면 우측 정렬이 깨진다).
    expect(
      bar.right -
          tester
              .getRect(find.byKey(const ValueKey('web-header-account')))
              .right,
      closeTo(DpSpacing.xl, 1),
      reason: '계정 버튼이 오른쪽 끝에 붙지 않았다',
    );
  });

  // 우측 그룹을 non-flex 로 둔 대가. 비(非)compact 하한인 720 에서도 넘치지
  // 않아야 한다 — 넘치면 clipBehavior 기본값(Clip.none) 때문에 드롭다운이
  // 검색 상자 위에 겹쳐 그려진다.
  testWidgets('720(비compact 하한): 헤더가 오버플로하지 않는다', (tester) async {
    _setWidth(tester, 720);
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('720 · 텍스트 200% 에서 헤더가 오버플로하지 않는다', (tester) async {
    _setWidth(tester, 720);
    await tester.pumpWidget(_host(textScale: 2.0));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('헤더 높이는 계약의 headerHeight(56)다', (tester) async {
    _setWidth(tester, 1240);
    await tester.pumpWidget(_host());

    final bar = tester.getSize(find.byKey(const ValueKey('web-header-bar')));
    expect(bar.height, AppTokens.standard.headerHeight);
  });

  testWidgets('compact: 주 메뉴·검색은 감추고 햄버거만 남는다', (tester) async {
    _setWidth(tester, 390);
    await tester.pumpWidget(_host());

    expect(find.byKey(const ValueKey('web-header-burger')), findsOneWidget);
    expect(find.byKey(const ValueKey('web-header-search')), findsNothing);
    expect(find.byKey(const ValueKey('web-header-nav')), findsNothing);
  });

  testWidgets('compact: 햄버거를 누르면 접힘 메뉴가 헤더 아래로 펼쳐진다 — 게시판 셋과 계정 항목이 들어 있다', (
    tester,
  ) async {
    _setWidth(tester, 390);
    await tester.pumpWidget(_host());

    await tester.tap(find.byKey(const ValueKey('web-header-burger')));
    await tester.pumpAndSettle();

    final menu = find.byKey(const ValueKey('web-header-collapsed-menu'));
    expect(menu, findsOneWidget);
    for (final label in [
      '오늘',
      '학습 경로',
      '자유게시판',
      'Q/A',
      '마이페이지',
      '설정',
      '로그아웃',
    ]) {
      expect(
        find.descendant(of: menu, matching: find.text(label)),
        findsOneWidget,
        reason: '$label 이 접힘 메뉴에 없으면 폰에서 도달할 방법이 사라진다',
      );
    }

    final header = tester.getRect(find.byKey(const ValueKey('web-header-bar')));
    expect(
      tester.getRect(menu).top,
      greaterThanOrEqualTo(header.bottom),
      reason: '오버레이가 아니라 헤더 아래 인라인 확장이어야 한다(스펙 §5.3)',
    );
  });

  testWidgets('접힘 메뉴 항목을 고르면 메뉴가 닫히고 onSelect 가 불린다', (tester) async {
    _setWidth(tester, 390);
    String? picked;
    await tester.pumpWidget(_host(onSelect: (id) => picked = id));

    await tester.tap(find.byKey(const ValueKey('web-header-burger')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Q/A'));
    await tester.pumpAndSettle();

    expect(picked, '/community?board=QNA');
    expect(
      find.byKey(const ValueKey('web-header-collapsed-menu')),
      findsNothing,
    );
  });

  // Review Focus 1
  testWidgets('접힘 메뉴를 연 채 폭이 넓어지면 접힘 상태가 풀린다', (tester) async {
    _setWidth(tester, 390);
    await tester.pumpWidget(_host());
    await tester.tap(find.byKey(const ValueKey('web-header-burger')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('web-header-collapsed-menu')),
      findsOneWidget,
    );

    tester.view.physicalSize = const Size(1240, 900);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('web-header-collapsed-menu')),
      findsNothing,
      reason: '닫을 버튼이 사라진 채 메뉴만 남으면 빠져나올 수 없다',
    );

    // 여기까지는 build 의 `if (compact && _expanded)` 만으로도 통과한다 —
    // 즉 위 단언만으로는 리셋을 지워도 초록이다. 진짜 계약은 **다시 좁혔을 때**
    // 메뉴가 저절로 열려 있지 않은 것이다.
    tester.view.physicalSize = const Size(390, 900);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('web-header-collapsed-menu')),
      findsNothing,
      reason: '넓혔다 좁혔더니 열어 본 적 없는 메뉴가 펼쳐져 있다',
    );
  });

  testWidgets('현재 항목에만 밑줄이 있다 — 매칭 실패면 아무 데도 없다', (tester) async {
    _setWidth(tester, 1240);
    await tester.pumpWidget(_host(selectedId: '/path'));
    expect(
      tester.widget<DpWebHeader>(find.byType(DpWebHeader)).selectedId,
      '/path',
    );
    expect(
      find.byKey(const ValueKey('web-header-current-/path')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('web-header-current-/dashboard')),
      findsNothing,
    );

    await tester.pumpWidget(_host());
    expect(find.byKeyValue(startsWith: 'web-header-current-'), findsNothing);
  });

  testWidgets('커뮤니티 자식이 현재면 부모에 밑줄이 간다', (tester) async {
    _setWidth(tester, 1240);
    await tester.pumpWidget(_host(selectedId: '/community?board=QNA'));
    expect(
      find.byKey(const ValueKey('web-header-current-/community')),
      findsOneWidget,
    );
  });

  // Review Focus 4
  testWidgets('390 폭 · 텍스트 200% 에서 헤더가 오버플로하지 않는다', (tester) async {
    _setWidth(tester, 390);
    await tester.pumpWidget(_host(textScale: 2.0));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  // browser-ux 는 햄버거를 `getByRole('button', { name: '메뉴' })` 로 찾는다.
  // 라벨이 바뀌면 그 시나리오가 30초 타임아웃으로 죽는다(2026-09-26 실측) — 여기서 못박는다.
  testWidgets('햄버거의 시맨틱 라벨은 정확히 "메뉴" 다(browser-ux 선택자 계약)', (tester) async {
    final handle = tester.ensureSemantics();

    _setWidth(tester, 390);
    await tester.pumpWidget(_host());

    final node = tester.getSemantics(
      find.byKey(const ValueKey('web-header-burger')),
    );
    expect(node.label, '메뉴');
    expect(
      node.rect.shortestSide,
      greaterThanOrEqualTo(DpDensity.minTarget),
      reason: '위젯 크기가 아니라 시맨틱 박스가 2.5.8 기준이다',
    );
    handle.dispose();
  });

  testWidgets('접힘 메뉴의 모든 항목은 최소 타깃 24 이상이다', (tester) async {
    // getSemantics 는 시맨틱스가 켜져 있어야 한다 — 핸들 없이 부르면 던진다.
    // 해제는 본문 끝에서 명시적으로 한다: 핸들 검증이 tearDown 콜백보다 **먼저**
    // 돌아서 addTearDown(handle.dispose) 는 늦는다(실측, 레포의 기존 패턴과 동일).
    final handle = tester.ensureSemantics();

    _setWidth(tester, 390);
    await tester.pumpWidget(_host());
    await tester.tap(find.byKey(const ValueKey('web-header-burger')));
    await tester.pumpAndSettle();

    for (final label in ['오늘', '자유게시판', '로그아웃']) {
      final rect = tester.getSemantics(find.text(label)).rect;
      expect(
        rect.height,
        greaterThanOrEqualTo(DpDensity.minTarget),
        reason: '$label 의 시맨틱 박스가 ${rect.height} — 위젯 크기가 아니라 이 값이 2.5.8 기준이다',
      );
    }
    handle.dispose();
  });
}

/// `find.byKey` 는 정확한 키만 찾는다 — 접두사로 「어떤 현재 항목도 없음」을 재려면 술어가 필요하다.
extension on CommonFinders {
  Finder byKeyValue({required String startsWith}) =>
      find.byWidgetPredicate((w) {
        final key = w.key;
        return key is ValueKey<String> && key.value.startsWith(startsWith);
      });
}
