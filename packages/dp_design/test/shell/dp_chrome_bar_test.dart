import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _crumbs = <DpCrumb>[
  (label: '커뮤니티', path: null),
  (label: '게시판', path: '/community'),
  (label: '게시글', path: null),
];

Widget _host(Widget child) => MaterialApp(
  theme: DpTheme.light(),
  home: Scaffold(body: child),
);

void main() {
  testWidgets('모든 세그먼트를 렌더한다', (tester) async {
    await tester.pumpWidget(_host(const DpChromeBar(breadcrumb: _crumbs)));
    expect(find.text('커뮤니티'), findsOneWidget);
    expect(find.text('게시판'), findsOneWidget);
    expect(find.text('게시글'), findsOneWidget);
  });

  testWidgets('path 있는 세그먼트만 탭 시 경로 통지', (tester) async {
    String? tapped;
    await tester.pumpWidget(
      _host(DpChromeBar(breadcrumb: _crumbs, onCrumbTap: (p) => tapped = p)),
    );
    await tester.tap(find.text('게시판'));
    expect(tapped, '/community');

    tapped = null;
    await tester.tap(find.text('커뮤니티'));
    expect(tapped, isNull, reason: 'path가 null인 세그먼트는 비클릭이다');
  });

  testWidgets('검색 필드 탭은 onSearchTap을 호출', (tester) async {
    var opened = false;
    await tester.pumpWidget(
      _host(DpChromeBar(breadcrumb: _crumbs, onSearchTap: () => opened = true)),
    );
    await tester.tap(find.byKey(const ValueKey('chrome-search')));
    expect(opened, isTrue);
  });

  testWidgets('compact은 마지막 세그먼트만 + 검색 아이콘', (tester) async {
    await tester.pumpWidget(
      _host(
        DpChromeBar(breadcrumb: _crumbs, compact: true, onSearchTap: () {}),
      ),
    );
    expect(find.text('게시글'), findsOneWidget);
    expect(find.text('커뮤니티'), findsNothing);
    expect(find.byKey(const ValueKey('chrome-search-icon')), findsOneWidget);
    expect(find.byKey(const ValueKey('chrome-search')), findsNothing);
  });

  testWidgets('actions·account 슬롯을 렌더', (tester) async {
    await tester.pumpWidget(
      _host(
        const DpChromeBar(
          breadcrumb: _crumbs,
          actions: [Text('액션')],
          account: Text('계정'),
        ),
      ),
    );
    expect(find.text('액션'), findsOneWidget);
    expect(find.text('계정'), findsOneWidget);
  });

  // Minor: onSearchTap 부재 시 compact 여부와 무관하게 검색 UI가 렌더되지 않아야
  // 일관적이다(비-compact은 이미 그렇다).
  testWidgets('onSearchTap이 없으면 compact에서도 검색 아이콘이 없다', (tester) async {
    await tester.pumpWidget(
      _host(const DpChromeBar(breadcrumb: _crumbs, compact: true)),
    );
    expect(find.byKey(const ValueKey('chrome-search-icon')), findsNothing);
    expect(find.byKey(const ValueKey('chrome-search')), findsNothing);
  });

  // Important 1: 세그먼트 Text가 Row(mainAxisSize.min) 아래에서 자기 폭 제약이
  // 없으면 ellipsis가 발동하지 않고 RenderFlex 오버플로가 난다.
  testWidgets('좁은 폭 + 긴 라벨에서도 오버플로 없이 렌더된다', (tester) async {
    tester.view.physicalSize = const Size(400, 200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final longCrumbs = <DpCrumb>[
      (label: List.filled(45, '가').join(), path: null),
      (label: List.filled(45, '나').join(), path: '/x'),
    ];

    await tester.pumpWidget(_host(DpChromeBar(breadcrumb: longCrumbs)));

    expect(tester.takeException(), isNull);
  });

  // Important 2: DESIGN.md §6 — 터치 타깃 ≥44×44. 클릭 가능한 세그먼트와
  // 검색 필드 모두 히트 영역이 44px 이상이어야 한다.
  testWidgets('클릭 가능한 브레드크럼 세그먼트의 탭 영역이 44px 이상', (tester) async {
    await tester.pumpWidget(
      _host(DpChromeBar(breadcrumb: _crumbs, onCrumbTap: (_) {})),
    );
    final finder = find.ancestor(
      of: find.text('게시판'),
      matching: find.byType(InkWell),
    );
    expect(tester.getSize(finder).height, greaterThanOrEqualTo(44));
  });

  testWidgets('검색 필드의 탭 영역이 44px 이상(시각적 상자는 28px 유지)', (tester) async {
    await tester.pumpWidget(
      _host(DpChromeBar(breadcrumb: _crumbs, onSearchTap: () {})),
    );
    final size = tester.getSize(find.byKey(const ValueKey('chrome-search')));
    expect(size.height, greaterThanOrEqualTo(44));
  });

  // Important 3: 색 토큰이 실제로 배선됐는지 — 지금까지의 5테스트는 텍스트·키
  // 존재와 탭 콜백만 확인해 textFaint/textSecondary를 바꿔치기해도 통과했다.
  testWidgets('바 배경·아래 경계가 surface/border 토큰을 쓴다', (tester) async {
    await tester.pumpWidget(_host(const DpChromeBar(breadcrumb: _crumbs)));
    final container = tester.widget<Container>(
      find.byKey(const ValueKey('chrome-bar-root')),
    );
    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.color, DpColors.light.surface);
    expect(decoration.border!.bottom.color, DpColors.light.border);
  });

  testWidgets('세그먼트 라벨과 구분자가 서로 다른 색 토큰을 쓴다(뒤바뀌지 않음)', (tester) async {
    await tester.pumpWidget(_host(const DpChromeBar(breadcrumb: _crumbs)));
    final segment = tester.widget<Text>(find.text('게시판'));
    expect(segment.style?.color, DpColors.light.textSecondary);

    final separator = tester.widget<Text>(find.text('·').first);
    expect(separator.style?.color, DpColors.light.textFaint);
  });

  // Important 1: 밝은 surface 배경 위이므로 actions·account에 무스타일
  // 위젯을 넣어도 textSecondary가 기본 전경색으로 공급돼야 한다(대비 확보).
  testWidgets('actions·account 슬롯은 textSecondary를 기본 전경색으로 제공', (tester) async {
    Color? actionsIconColor;
    Color? accountTextColor;
    await tester.pumpWidget(
      _host(
        DpChromeBar(
          breadcrumb: _crumbs,
          actions: [
            Builder(
              builder: (context) {
                actionsIconColor = IconTheme.of(context).color;
                return const Icon(Icons.notifications);
              },
            ),
          ],
          account: Builder(
            builder: (context) {
              accountTextColor = DefaultTextStyle.of(context).style.color;
              return const Text('계정');
            },
          ),
        ),
      ),
    );
    expect(actionsIconColor, DpColors.light.textSecondary);
    expect(accountTextColor, DpColors.light.textSecondary);
  });

  // I2(이월, 3단계 확정): 이전 fix wave가 여기 붙였던 "폭 600, 액션 4개도
  // 오버플로 없음" 가드는 컨트롤러(2차 fix wave)의 지시로 제거했다 —
  // 그 테스트는 자신의 주석에서 스스로 "수정 전에도 이미 안전한 폭이라
  // red-repro가 아니다"라고 인정하고 있었다(actions 그룹을 flex 참여자로
  // 만들면 오히려 예산이 줄어 더 좁은 폭에서 터진다는 실측까지 남겼다).
  // 그 사이 원인이 된 LayoutBuilder+ConstrainedBox(maxWidth: 폭/2)도
  // dp_chrome_bar.dart에서 원복했다(임계가 W<G+16 → W<2G로 오히려
  // 넓어지는 회귀였다 — second-fix-report.md 참고). I2 자체(non-flex
  // actions·account 그룹의 오버플로) 해법은 crumbs flex 가중치·그룹
  // 축약(overflow 메뉴) 설계와 함께 3단계에서 다룬다. 지키지 못하는
  // 가드를 지키는 것처럼 남기지 않기 위해 그냥 제거한다.

  // 역함정 가드: DpPageHeader에서 actions를 Flexible로 감쌌다가 형제
  // Expanded와 50/50으로 갈려 우측 정렬이 깨진 전례가 있다(dp_page_header.dart
  // 주석 참조). 여기서도 group을 flex 참여자로 바꾸면서 우측 정렬이
  // 깨지지 않았는지 고정한다 — account가 바 우측 끝에서 패딩(16px)만큼만
  // 떨어져 있어야 한다.
  //
  // crumbs는 자기 flex 몫을 다 쓸 만큼 긴 라벨을 쓴다 — 실측 결과 crumbs가
  // 짧으면(예: 기본 _crumbs) Flexible(loose fit)이 자기 몫을 다 소비하지
  // 않아 남는 공간이 Spacer 뒤로 재분배되지 않고 바 맨 끝에 그대로
  // 남는다(이 파일의 Flexible(crumbs)+Spacer 구성 자체의 기존 특성 —
  // 수정 전 원본 코드로도 동일하게 재현 확인, I2 범위 밖). 이 테스트는
  // 그 사전 혼입 없이 group 자체의 우측 정렬만 검증한다.
  testWidgets('넉넉한 폭 + 긴 crumbs에서 account는 바 우측 끝에 붙는다(우측 정렬 유지)', (
    tester,
  ) async {
    final longCrumbs = <DpCrumb>[
      (label: List.filled(60, '가').join(), path: null),
    ];
    await tester.pumpWidget(
      _host(
        DpChromeBar(
          breadcrumb: longCrumbs,
          actions: const [Text('액션')],
          account: const Icon(Icons.account_circle, key: ValueKey('acct')),
        ),
      ),
    );
    final barRight = tester
        .getRect(find.byKey(const ValueKey('chrome-bar-root')))
        .right;
    final acctRight = tester.getRect(find.byKey(const ValueKey('acct'))).right;
    expect(barRight - acctRight, closeTo(DpSpacing.lg, 1.0));
  });

  testWidgets('검색 필드 배경은 surfaceMuted를 쓴다', (tester) async {
    await tester.pumpWidget(
      _host(DpChromeBar(breadcrumb: _crumbs, onSearchTap: () {})),
    );
    final container = tester.widget<Container>(
      find
          .descendant(
            of: find.byKey(const ValueKey('chrome-search')),
            matching: find.byType(Container),
          )
          .first,
    );
    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.color, DpColors.light.surfaceMuted);
  });
}
