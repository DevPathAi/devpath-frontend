import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host({required List<DpCrumb> crumbs, void Function(String)? onTap}) =>
    MaterialApp(
      theme: DpTheme.light(),
      home: Scaffold(
        body: DpBreadcrumb(crumbs: crumbs, onCrumbTap: onTap),
      ),
    );

void main() {
  testWidgets('세그먼트와 › 구분자를 낸다', (tester) async {
    await tester.pumpWidget(
      _host(
        crumbs: const [
          (label: '커뮤니티', path: '/community'),
          (label: 'Q/A', path: null),
        ],
      ),
    );

    expect(find.text('커뮤니티'), findsOneWidget);
    expect(find.text('Q/A'), findsOneWidget);
    expect(find.text('›'), findsOneWidget);
  });

  testWidgets('마지막 세그먼트는 path 가 있어도 링크가 아니다', (tester) async {
    String? tapped;
    await tester.pumpWidget(
      _host(
        crumbs: const [
          (label: '커뮤니티', path: '/community'),
          (label: '자유게시판', path: '/community?board=FREE'),
        ],
        onTap: (p) => tapped = p,
      ),
    );

    await tester.tap(find.text('자유게시판'));
    await tester.pump();
    expect(tapped, isNull, reason: '자기 자신으로 가는 링크를 두지 않는다(브레드크럼 관례)');

    await tester.tap(find.text('커뮤니티'));
    await tester.pump();
    expect(tapped, '/community');
  });

  testWidgets('빈 목록이면 자리를 차지하지 않는다', (tester) async {
    await tester.pumpWidget(_host(crumbs: const []));

    // 계획의 `find.byType(SizedBox), findsWidgets` 는 Scaffold 만으로도 참이라
    // 어떤 구현에서도 통과한다 — 실제로 무엇을 보장하는지로 바꿨다.
    expect(tester.getSize(find.byType(DpBreadcrumb)).height, 0);
    expect(find.text('›'), findsNothing);
  });

  testWidgets('링크 세그먼트의 시맨틱 박스는 최소 타깃 24 이상이다', (tester) async {
    // 해제는 본문 끝에서 명시적으로 한다 — 핸들 검증이 tearDown 보다 먼저 돈다.
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(
      _host(
        crumbs: const [
          (label: '커뮤니티', path: '/community'),
          (label: 'Q/A', path: null),
        ],
      ),
    );

    expect(
      tester.getSemantics(find.text('커뮤니티')).rect.height,
      greaterThanOrEqualTo(DpDensity.minTarget),
    );
    handle.dispose();
  });

  // 리뷰 실측(2026-09-26): 같은 Wrap+Align 확장으로 세그먼트가 세로로 쌓였다
  // (1240 폭에서 높이 120px, 구분자는 혼자 떠 있었다).
  testWidgets('세그먼트는 한 줄에 놓인다 — 세로로 쌓이지 않는다', (tester) async {
    tester.view.physicalSize = const Size(1240, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _host(
        crumbs: const [
          (label: '커뮤니티', path: '/community'),
          (label: '자유게시판', path: '/community?board=FREE'),
          (label: '게시글', path: null),
        ],
      ),
    );

    final height = tester.getSize(find.byType(DpBreadcrumb)).height;
    expect(
      height,
      lessThan(48),
      reason: '한 줄이면 최소 타깃 24 수준이다. $height 는 세그먼트가 줄마다 쌓였다는 뜻',
    );
    final first = tester.getRect(find.text('커뮤니티'));
    final last = tester.getRect(find.text('게시글'));
    expect(first.top, closeTo(last.top, 2), reason: '같은 줄이면 top 이 같다');
  });

  // CI 실측(36215681312): 390x200% 에서 차단된 외부 요청 724건 중 **695건이
  // notosanssymbols** 였다. 좁은 폭에서 세그먼트가 잘리며 ellipsis(…, U+2026)를
  // 그리는데 그 글자가 번들 폰트에 없어 CanvasKit 이 폰트를 계속 다시 받는다.
  // `DpChromeBar._crumbs` 는 compact 에서 마지막 세그먼트만 보여 이 문제가 없다 —
  // 같은 규칙을 따른다(폰 화면에서 전체 경로는 어차피 읽히지 않는다).
  testWidgets('compact 에서는 마지막 세그먼트만 보여 잘림이 생기지 않는다', (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _host(
        crumbs: const [
          (label: '커뮤니티', path: '/community'),
          (label: '자유게시판', path: '/community?board=FREE'),
          (label: '게시글', path: null),
        ],
      ),
    );

    expect(find.text('게시글'), findsOneWidget);
    expect(find.text('커뮤니티'), findsNothing);
    expect(find.text('자유게시판'), findsNothing);
    expect(find.text('›'), findsNothing, reason: '한 개뿐이면 구분자도 없다');
  });
}
