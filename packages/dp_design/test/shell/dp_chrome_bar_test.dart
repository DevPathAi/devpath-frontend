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
        DpChromeBar(
          breadcrumb: _crumbs,
          actions: [
            DpChromeAction(icon: Icons.star, label: '액션', onPressed: (_) {}),
          ],
          account: const Text('계정'),
        ),
      ),
    );
    expect(find.byTooltip('액션'), findsOneWidget);
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

  // Important 1: 밝은 surface 배경 위이므로 actions·account 모두 textSecondary가
  // 기본 전경색으로 공급돼야 한다(대비 확보). actions는 이제 DpChromeBar가
  // 직접 IconButton을 짓는 데이터형이라(3단계 I2) ambient IconTheme 상속을
  // 검증할 수 없다 — IconButton은 자기 테마로 색을 정하고 ambient를
  // 상속하지 않기 때문에, DpChromeBar가 명시적으로 textSecondary를 칠하는지
  // 렌더된 Icon의 color 필드로 직접 확인한다. account는 여전히 호출부가
  // 넘기는 무스타일 위젯이라 ambient DefaultTextStyle 상속을 그대로 검증한다.
  testWidgets('actions는 textSecondary를 아이콘 색으로 쓰고, account는 ambient를 상속한다', (
    tester,
  ) async {
    Color? accountTextColor;
    await tester.pumpWidget(
      _host(
        DpChromeBar(
          breadcrumb: _crumbs,
          actions: [
            DpChromeAction(
              icon: Icons.notifications,
              label: '알림',
              onPressed: (_) {},
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
    final actionIcon = tester.widget<Icon>(find.byIcon(Icons.notifications));
    expect(actionIcon.color, DpColors.light.textSecondary);
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
  // 주석 참조). actions·account 그룹이 non-flex로 남아 우측 끝에 붙는지
  // 고정한다 — account가 바 우측 끝에서 패딩(16px)만큼만 떨어져 있어야 한다.
  //
  // 이 케이스는 crumbs가 자기 폭 몫을 다 쓰는 경로를 덮는다(60자 라벨).
  // crumbs가 짧아 몫을 남기는 경로는 아래 '실제 앱처럼 짧은 crumbs' 테스트가
  // 따로 덮는다 — 예전 Flexible+Spacer 구성에서는 그 경로만 정렬이 깨졌고,
  // 이 테스트는 긴 라벨을 써서 그 결함을 우회하고 있었다.
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
          actions: [
            DpChromeAction(icon: Icons.star, label: '액션', onPressed: (_) {}),
          ],
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

  // 위 테스트가 60자짜리 crumbs를 쓴 이유가 바로 이 결함이다 — 짧은 crumbs로는
  // 통과하지 못해서였다. 2단계 육안 확인(1000·1400폭 실빌드 캡처)에서 오류 신고
  // 아이콘이 바 우측이 아니라 한참 왼쪽에 찍혔고, 폭이 커질수록 여백이 그만큼
  // 커졌다(1000폭 약 148px → 1400폭 약 448px).
  //
  // 원인: Flexible(loose fit)은 자기 flex 몫보다 적게 쓸 수 있는데, 그 잔여는
  // Spacer(Expanded=tight)로 재분배되지 않고 Row 끝에 그대로 남는다. Spacer는
  // freeSpace * 1/totalFlex 만큼만 받으므로 crumbs·search가 몫을 남기면 그
  // 잔여폭이 actions 그룹 오른쪽에 빈 공간으로 쌓인다. 실제 앱 crumbs는
  // '학습 · 대시보드' 수준으로 짧아 항상 이 경로를 탄다.
  testWidgets('실제 앱처럼 짧은 crumbs에서도 actions는 바 우측 끝에 붙는다', (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _host(
        DpChromeBar(
          breadcrumb: const [
            (label: '학습', path: null),
            (label: '대시보드', path: null),
          ],
          onSearchTap: () {},
          actions: [
            DpChromeAction(
              icon: Icons.error_outline,
              label: '오류',
              onPressed: (_) {},
            ),
          ],
        ),
      ),
    );

    final barRight = tester
        .getRect(find.byKey(const ValueKey('chrome-bar-root')))
        .right;
    // 액션은 이제 DpChromeBar가 짓는 IconButton(히트 타깃 포함)이라, 그
    // 바깥 경계(IconButton 자체의 rect)로 정렬을 확인한다 — 안쪽 Icon
    // 글리프나 Tooltip 위젯의 rect는 IconButton 내부 히트 영역 패딩만큼
    // 안쪽으로 치우쳐 보여 실측이 4px 어긋난다(직접 확인).
    final actRight = tester
        .getRect(find.widgetWithIcon(IconButton, Icons.error_outline))
        .right;
    expect(barRight - actRight, closeTo(DpSpacing.lg, 1.0));
  });

  // 링크 세그먼트만 탭 타깃 확보용 수평 패딩(sm)을 갖는 탓에 구분자가 한쪽으로
  // 밀려 보였다 — 2단계 육안 확인의 커뮤니티 화면('커뮤니티 · 게시판')에서
  // '·'가 왼쪽 라벨에 붙고 오른쪽만 벌어졌다. 구분자는 좌우 텍스트로부터 같은
  // 거리에 있어야 한다(링크 여부와 무관).
  //
  // _crumbs는 비링크→링크(첫 구분자)와 링크→비링크(둘째 구분자)를 모두 포함해
  // 두 조합을 한 번에 덮는다.
  testWidgets('구분자는 링크 여부와 무관하게 좌우 같은 간격을 갖는다', (tester) async {
    await tester.pumpWidget(_host(const DpChromeBar(breadcrumb: _crumbs)));

    final dots = find.text('·');
    expect(dots, findsNWidgets(2));

    for (final (i, pair) in [('커뮤니티', '게시판'), ('게시판', '게시글')].indexed) {
      final dot = tester.getRect(dots.at(i));
      final gapBefore = dot.left - tester.getRect(find.text(pair.$1)).right;
      final gapAfter = tester.getRect(find.text(pair.$2)).left - dot.right;
      expect(
        gapBefore,
        closeTo(gapAfter, 0.5),
        reason: '${pair.$1} · ${pair.$2} 구분자 간격이 좌우 비대칭이다',
      );
    }
  });

  // 3-A: 마지막 세그먼트는 현재 위치이므로 path가 있어도 비링크로 렌더해야
  // 한다(브레드크럼 관례 — 자기 자신으로 가는 링크를 두지 않는다).
  testWidgets('마지막 crumb은 path가 있어도 비링크다', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(
      _host(
        DpChromeBar(
          breadcrumb: const [
            (label: '커뮤니티', path: null),
            (label: '게시판', path: '/community'),
          ],
          onCrumbTap: (_) => tapped++,
        ),
      ),
    );

    // 현재 위치를 자기 자신에게 링크하지 않는다(브레드크럼 관례).
    await tester.tap(find.text('게시판'));
    await tester.pump();
    expect(tapped, 0);
  });

  testWidgets('마지막이 아닌 crumb은 path가 있으면 링크다', (tester) async {
    var tappedPath = '';
    await tester.pumpWidget(
      _host(
        DpChromeBar(
          breadcrumb: const [
            (label: '커뮤니티', path: null),
            (label: '게시판', path: '/community'),
            (label: '게시글', path: null),
          ],
          onCrumbTap: (p) => tappedPath = p,
        ),
      ),
    );

    await tester.tap(find.text('게시판'));
    await tester.pump();
    expect(tappedPath, '/community');
  });

  // Important(리뷰 발견 1): dp_chrome_bar.dart의 구분자 패딩 상쇄 조건
  // (`i + 1 == items.length - 1`)은 "마지막 항목이 path를 가진" 경우에만
  // 의미가 갈린다. 위쪽 `_crumbs` 고정 픽스처는 마지막이 이미 path: null이라
  // 이 분기를 통과하지 않는다 — 이 테스트가 그 경로를 전담해서 잠근다.
  // (컨트롤러 리뷰로 이 조건을 제거하면 정확히 DpSpacing.sm(8px)만큼
  // 비대칭이 재현됨을 실측 확인했다 — task-5-report.md 참고.)
  testWidgets('마지막 crumb이 path를 가져도 구분자 간격은 대칭이다', (tester) async {
    await tester.pumpWidget(
      _host(
        const DpChromeBar(
          breadcrumb: [
            (label: '커뮤니티', path: null),
            (label: '게시판', path: '/community'),
          ],
        ),
      ),
    );

    final dot = tester.getRect(find.text('·'));
    final gapBefore = dot.left - tester.getRect(find.text('커뮤니티')).right;
    final gapAfter = tester.getRect(find.text('게시판')).left - dot.right;
    expect(
      gapBefore,
      closeTo(gapAfter, 0.5),
      reason: '커뮤니티 · 게시판(마지막, path 있음) 구분자 간격이 좌우 비대칭이다',
    );
  });

  // Minor(리뷰 발견 3): compact은 crumbs를 마지막 1개로 잘라 렌더한다
  // (`_crumbs`의 `compact && breadcrumb.isNotEmpty ? [breadcrumb.last] : ...`).
  // 그 단일 항목이 path를 가진 경우에도 비링크여야 한다 — 기존 compact
  // 테스트(위 '검색 아이콘' 테스트)의 픽스처(게시글, path: null)는 이
  // 조합을 우연히 피해간다.
  testWidgets('compact에서 유일한(마지막) crumb이 path를 가져도 비링크다', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(
      _host(
        DpChromeBar(
          breadcrumb: const [
            (label: '커뮤니티', path: null),
            (label: '게시판', path: '/community'),
          ],
          compact: true,
          onCrumbTap: (_) => tapped++,
        ),
      ),
    );

    expect(find.text('게시판'), findsOneWidget);
    expect(find.text('커뮤니티'), findsNothing);

    await tester.tap(find.text('게시판'));
    await tester.pump();
    expect(tapped, 0);
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
