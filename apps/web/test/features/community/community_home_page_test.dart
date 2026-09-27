import 'package:devpath_web/src/features/ads/presentation/ad_slot_widget.dart';
import 'package:devpath_web/src/features/community/data/community_source.dart';
import 'package:devpath_web/src/features/community/presentation/community_home_page.dart';
import 'package:devpath_web/src/features/community/state/community_state.dart';
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

CommunityPostSummary _p(
  int id, {
  String? title,
  bool solved = false,
  String boardType = 'QNA',
  int upvoteCount = 0,
}) => CommunityPostSummary(
  id: id,
  title: title ?? '글 $id',
  boardType: boardType,
  solved: solved,
  replyCount: 1,
  upvoteCount: upvoteCount,
);

/// 운영 라우터와 같은 모양: `/community?board=` 가 게시판을 정한다.
GoRouter _router({String initialLocation = '/community'}) => GoRouter(
  initialLocation: initialLocation,
  routes: [
    GoRoute(
      path: '/community',
      builder: (_, state) => CommunityHomePage(
        initialBoard: state.uri.queryParameters['board'],
        initialQuery: state.uri.queryParameters['q'],
      ),
    ),
    GoRoute(path: '/community/new', builder: (_, _) => const Text('작성 화면')),
    GoRoute(
      path: '/community/new/post',
      builder: (_, state) =>
          Text('일반 작성 화면 ${state.uri.queryParameters['board']}'),
    ),
    GoRoute(
      path: '/community/post/:id',
      builder: (_, _) => const Text('일반 상세 화면'),
    ),
    GoRoute(path: '/community/:id', builder: (_, _) => const Text('상세 화면')),
  ],
);

Widget _host(ProviderContainer c, {GoRouter? router}) =>
    UncontrolledProviderScope(
      container: c,
      child: MaterialApp.router(
        theme: DpTheme.light(),
        routerConfig: router ?? _router(),
      ),
    );

ProviderContainer _container(
  List<CommunityPostSummary> posts, {
  List<String?>? seen,
}) {
  final c = ProviderContainer(
    overrides: [
      communityListProvider.overrideWithValue(({
        String? board,
        String? tag,
        String? sort,
      }) async {
        seen?.add(board);
        return posts;
      }),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  testWidgets('목록을 렌더한다(작성자 이름 없이 메타 표시)', (tester) async {
    final c = _container([_p(1, title: 'async 질문')]);
    // 칼럼 라벨은 **게시판**에서 나온다(칼럼은 행마다 다른 라벨을 가질 수 없다).
    // 옛 `CommunityPostRow` 는 행의 `boardType` 으로 답변/댓글을 골랐으므로,
    // QNA 행을 기본(자유게시판) 목록에 넣어도 「답변」이 나왔다. 이제는 게시판을
    // 명시해야 한다.
    await tester.pumpWidget(
      _host(c, router: _router(initialLocation: '/community?board=QNA')),
    );
    await tester.pumpAndSettle();
    expect(find.text('async 질문'), findsOneWidget);
    // 「답변 N · 추천 M」 한 줄이 숫자 칼럼 둘로 갈라졌다(시안 `<thead>`).
    expect(find.text('답변'), findsOneWidget); // 칼럼 라벨
    expect(find.text('1'), findsOneWidget); // 답변 1 (추천은 0)
  });

  testWidgets('semanticChildCount는 광고를 제외한 게시글 수다', (tester) async {
    // 광고 슬롯은 5번째 게시글 뒤에 끼어들어 itemCount를 1 늘린다.
    // 스크린리더가 읽는 「N개 중 M번째」의 N은 **목록 항목만** 세야 한다 —
    // 틀린 개수는 없는 것보다 나쁘다.
    //
    // SliverList는 lazy라 기본 뷰포트에서는 6번째 항목(광고)이 빌드되지 않는다.
    // 아래 「광고가 실제로 끼어들었는가」 검산이 성립하도록 세로를 넉넉히 준다.
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final c = _container([for (var i = 1; i <= 6; i++) _p(i)]);
    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();

    // 조건 성립 검산: 광고가 실제로 끼어든 상태인가(6 >= 임계 5).
    expect(find.byType(AdSlotWidget), findsOneWidget);

    final view = tester.widget<CustomScrollView>(find.byType(CustomScrollView));
    expect(view.semanticChildCount, 6);
  });

  testWidgets('빈 목록은 작성 CTA를 보인다', (tester) async {
    final c = _container(const []);
    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();
    expect(find.textContaining('첫 글'), findsOneWidget);
  });

  testWidgets('첫 로드 실패는 DpError와 재시도를 보인다', (tester) async {
    var calls = 0;
    final c = ProviderContainer(
      overrides: [
        communityListProvider.overrideWithValue(({
          String? board,
          String? tag,
          String? sort,
        }) async {
          calls++;
          if (calls == 1) {
            throw const ApiException(
              code: ApiErrorCode.network,
              message: '네트워크 오류',
            );
          }
          return [_p(1, title: '복구된 글')];
        }),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();
    expect(find.byType(DpError), findsOneWidget);

    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(find.text('복구된 글'), findsOneWidget);
  });

  for (final (board, label, destination) in [
    ('QNA', '질문하기', '작성 화면'),
    ('FREE', '글 작성', '일반 작성 화면 FREE'),
    ('FEEDBACK', '피드백 요청', '일반 작성 화면 FEEDBACK'),
  ]) {
    testWidgets('$board 게시판의 작성 버튼은 고르는 단계 없이 그 게시판 작성 화면으로 간다', (
      tester,
    ) async {
      final c = _container([_p(1, boardType: board)]);
      await tester.pumpWidget(
        _host(c, router: _router(initialLocation: '/community?board=$board')),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, label));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text(destination), findsOneWidget);
    });
  }

  testWidgets('빈 목록의 작성 행동도 현재 게시판 작성 화면으로 직행한다', (tester) async {
    final c = _container(const []);
    await tester.pumpWidget(
      _host(c, router: _router(initialLocation: '/community?board=QNA')),
    );
    await tester.pumpAndSettle();

    expect(find.text('아직 질문이 없어요'), findsOneWidget);
    // 빈 상태는 안내만 한다 — 작성 액션은 페이지 헤더의 상시 버튼 하나다
    // (같은 접근명이 둘이면 스크린리더로 구분할 수 없다. P3 이월을 P4 가 닫았다).
    expect(
      find.descendant(of: find.byType(DpEmpty), matching: find.text('질문하기')),
      findsNothing,
    );
    await tester.tap(
      find.descendant(
        of: find.byType(DpPageHeader),
        matching: find.text('질문하기'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('작성 화면'), findsOneWidget);
  });

  testWidgets('QNA 항목 탭은 Q/A 상세로 이동한다', (tester) async {
    final c = _container([_p(7, title: '탭할 글')]);
    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();

    await tester.tap(find.text('탭할 글'));
    await tester.pumpAndSettle();
    expect(find.text('상세 화면'), findsOneWidget);
  });

  testWidgets('게시판 페이지: 페이지 안 게시판 세그먼트·행 배지 없이 일반글 탭 라우팅', (tester) async {
    final c = _container([_p(10, title: '자유글', boardType: 'FREE')]);
    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();

    // 게시판 이동은 셸(레일)의 몫이다 — 본문은 다시 나누지 않는다.
    expect(find.byType(SegmentedButton<CommunityBoard>), findsNothing);
    // 제목은 어느 폭에서도 메뉴가 아니다(S3-P3).
    expect(find.byKey(const ValueKey('page-header-title-menu')), findsNothing);
    expect(find.text('자유글'), findsOneWidget);
    expect(find.text('자유게시판'), findsOneWidget); // 헤더뿐 — 행 배지 없음
    // FREE는 "댓글" 칼럼 라벨 + 숫자 칼럼(옛 「댓글 N · 추천 M」 한 줄을 대체).
    expect(find.text('댓글'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);

    // FREE 항목 탭 → 일반 상세 라우트
    await tester.tap(find.text('자유글'));
    await tester.pumpAndSettle();
    expect(find.text('일반 상세 화면'), findsOneWidget);
  });

  testWidgets('compact 폭에서 셸이 Q/A 로 보내면 그 게시판을 재조회한다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final seen = <String?>[];
    final c = _container([_p(10, title: '글')], seen: seen);
    final router = _router(initialLocation: '/community?board=FREE');
    await tester.pumpWidget(_host(c, router: router));
    await tester.pumpAndSettle();

    // S3-P3: 제목 메뉴를 없앴다. 좁은 폭의 게시판 이동은 셸 헤더의 햄버거
    // 메뉴가 맡으므로, 그 경로와 같은 모양으로 라우터를 움직인다.
    router.go('/community?board=QNA');
    await tester.pumpAndSettle();

    expect(
      router.routeInformationProvider.value.uri.toString(),
      '/community?board=QNA',
    );
    expect(seen, containsAllInOrder(['FREE', 'QNA']));
    expect(find.widgetWithText(FilledButton, '질문하기'), findsOneWidget);
  });

  testWidgets('initialBoard 쿼리로 진입 시 초기 필터가 반영된다', (tester) async {
    final seen = <String?>[];
    final c = _container(const [], seen: seen);
    await tester.pumpWidget(
      _host(c, router: _router(initialLocation: '/community?board=FEEDBACK')),
    );
    await tester.pumpAndSettle();
    expect(seen, contains('FEEDBACK'));
  });

  testWidgets('board 쿼리 없이 진입하면 자유게시판을 기본으로 조회한다', (tester) async {
    final seen = <String?>[];
    final c = _container(const [], seen: seen);

    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();

    expect(seen, contains('FREE'));
    expect(find.text('전체'), findsNothing);
    expect(find.text('자유게시판'), findsOneWidget); // 헤더
  });

  testWidgets('같은 화면에서 board URL만 바뀌어도 새 게시판을 조회한다', (tester) async {
    final seen = <String?>[];
    final c = _container(const [], seen: seen);
    final router = _router(initialLocation: '/community?board=FREE');

    await tester.pumpWidget(_host(c, router: router));
    await tester.pumpAndSettle();
    router.go('/community?board=QNA');
    await tester.pumpAndSettle();

    expect(seen, containsAllInOrder(['FREE', 'QNA']));
    expect(find.text('Q/A'), findsOneWidget); // 헤더
  });

  testWidgets('검색 입력 힌트는 현재 게시판 범위를 알린다', (tester) async {
    final c = _container(const []);
    await tester.pumpWidget(
      _host(c, router: _router(initialLocation: '/community?board=QNA')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Q/A에서 검색 (제목·본문·태그)'), findsOneWidget);
  });

  testWidgets('추천순 정렬은 재조회 없이 추천 수 내림차순(동률은 최신 우선)으로 바꾼다', (tester) async {
    final seen = <String?>[];
    final c = _container([
      _p(1, title: '추천 1', boardType: 'FREE', upvoteCount: 1),
      _p(2, title: '추천 5 최신', boardType: 'FREE', upvoteCount: 5),
      _p(3, title: '추천 5 이전', boardType: 'FREE', upvoteCount: 5),
    ], seen: seen);
    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();
    final loads = seen.length;

    double dy(String title) => tester.getTopLeft(find.text(title)).dy;
    // 기본은 서버 순서(최신순).
    expect(dy('추천 1'), lessThan(dy('추천 5 최신')));

    await tester.tap(find.byKey(const ValueKey('community-sort-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MenuItemButton, '추천순'));
    await tester.pumpAndSettle();

    expect(dy('추천 5 최신'), lessThan(dy('추천 5 이전')));
    expect(dy('추천 5 이전'), lessThan(dy('추천 1')));
    // 목록 API 는 sort 를 무시한다(전체 배열 반환) — 정렬은 클라이언트가 한다.
    expect(seen.length, loads);
  });

  testWidgets('셸 이동으로 q가 사라지면 검색 결과를 지우고 게시판 목록으로 복귀한다', (tester) async {
    final c = ProviderContainer(
      overrides: [
        communityListProvider.overrideWithValue(
          ({String? board, String? tag, String? sort}) async => [
            _p(1, title: '게시판 목록', boardType: 'FREE'),
          ],
        ),
        communitySearchProvider.overrideWithValue(
          ({
            required String q,
            String? board,
            String? tag,
            bool? solved,
            String? sort,
            int page = 0,
            int size = 20,
          }) async => CommunitySearchResult(
            items: [CommunitySearchItem(id: 2, title: '검색 결과', replyCount: 0)],
            total: 1,
          ),
        ),
      ],
    );
    addTearDown(c.dispose);
    final router = _router(initialLocation: '/community?board=FREE&q=flutter');

    await tester.pumpWidget(_host(c, router: router));
    await tester.pumpAndSettle();
    expect(find.text('검색 결과'), findsOneWidget);
    // 검색 결과는 관련도 순이라 목록 정렬을 적용하지 않는다.
    expect(
      tester
          .widget<TextButton>(
            find.descendant(
              of: find.byKey(const ValueKey('community-sort-menu')),
              matching: find.byType(TextButton),
            ),
          )
          .onPressed,
      isNull,
    );

    router.go('/community?board=FREE');
    await tester.pumpAndSettle();

    expect(find.text('검색 결과'), findsNothing);
    expect(find.text('게시판 목록'), findsOneWidget);
  });

  testWidgets('커뮤니티 목록: 390px 에서 본문이 가로로 넘치지 않고 표만 스크롤한다', (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final c = _container([_p(1, title: '좁은 폭 글', boardType: 'FREE')]);
    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byType(DpWebTable)).width,
      lessThanOrEqualTo(390),
    );
    // 칼럼 폭 합이 minWidth(640)보다 좁은 화면이라 표가 자체 가로 스크롤로 들어간다.
    expect(find.byKey(const ValueKey('dp-web-table-scroll')), findsOneWidget);
    // 그 스크롤 영역은 키보드로 닿을 수 있어야 한다(axe scrollable-region-focusable).
    expect(
      find.byKey(const ValueKey('dp-web-table-scroll-focus')),
      findsOneWidget,
    );
  });

  testWidgets('피드가 카드 나열이 아니라 표로 렌더된다', (tester) async {
    final c = _container([_p(1, title: '표 행', boardType: 'FREE')]);
    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();

    expect(find.byType(DpWebTable), findsOneWidget);
    expect(find.byType(DpListRow), findsNothing);
    expect(find.text('표 행'), findsOneWidget);
  });

  testWidgets('작성 버튼은 FAB 이 아니라 페이지 헤더 안에 있다', (tester) async {
    final c = _container([_p(10, title: '글', boardType: 'FREE')]);
    await tester.pumpWidget(
      _host(c, router: _router(initialLocation: '/community?board=FREE')),
    );
    await tester.pumpAndSettle();

    // 시안에 FAB 이 없다. 주요 액션은 페이지 헤더 우측 버튼이다.
    expect(find.byType(FloatingActionButton), findsNothing);
    final compose = find.widgetWithText(FilledButton, '글 작성');
    expect(compose, findsOneWidget);
    expect(
      find.ancestor(of: compose, matching: find.byType(DpPageHeader)),
      findsOneWidget,
    );
  });

  testWidgets('검색 중 게시판을 바꿔도 같은 검색어를 새 게시판에서 다시 조회한다', (tester) async {
    // S3-P3 에서 이 계약을 들고 있던 유일한 경로(제목 메뉴)가 사라졌고,
    // 셸 헤더는 q 를 떨군다. 사용자 결정으로 복원은 P4 다 —
    // 커버리지를 0 으로 두지 않기 위해 계약만 남긴다. P4 에서 셸 헤더의
    // 커뮤니티 하위 목적지가 현재 q 를 들고 가게 하면 이 테스트를 켠다.
    fail('S3-P4 에서 구현한다');
    // testWidgets 의 skip 은 bool 이다 — 사유는 위 주석과 이름에 남긴다.
  }, skip: true);
}
