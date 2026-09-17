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

const _titleMenu = ValueKey('page-header-title-menu');

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
    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();
    expect(find.text('async 질문'), findsOneWidget);
    expect(find.textContaining('답변 1'), findsOneWidget);
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

      await tester.tap(find.widgetWithText(FloatingActionButton, label));
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
    await tester.tap(
      find.descendant(of: find.byType(DpEmpty), matching: find.text('질문하기')),
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
    // 기본 테스트 폭(800)은 레일이 보이는 폭이라 제목도 메뉴가 아니다.
    expect(find.byKey(_titleMenu), findsNothing);
    expect(find.text('자유글'), findsOneWidget);
    expect(find.text('자유게시판'), findsOneWidget); // 헤더뿐 — 행 배지 없음
    // FREE는 "댓글" 라벨
    expect(find.textContaining('댓글 1'), findsOneWidget);

    // FREE 항목 탭 → 일반 상세 라우트
    await tester.tap(find.text('자유글'));
    await tester.pumpAndSettle();
    expect(find.text('일반 상세 화면'), findsOneWidget);
  });

  testWidgets('compact 폭에서는 제목 메뉴로 Q/A 로 이동하고 그 게시판을 재조회한다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final seen = <String?>[];
    final c = _container([_p(10, title: '글')], seen: seen);
    final router = _router(initialLocation: '/community?board=FREE');
    await tester.pumpWidget(_host(c, router: router));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(_titleMenu));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MenuItemButton, 'Q/A'));
    await tester.pumpAndSettle();

    expect(
      router.routeInformationProvider.value.uri.toString(),
      '/community?board=QNA',
    );
    expect(seen, containsAllInOrder(['FREE', 'QNA']));
    expect(find.widgetWithText(FloatingActionButton, '질문하기'), findsOneWidget);
  });

  testWidgets('검색 중 제목 메뉴로 게시판을 바꾸면 같은 검색어를 새 게시판에서 다시 조회한다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final searched = <(String, String?)>[];
    final c = ProviderContainer(
      overrides: [
        communityListProvider.overrideWithValue(
          ({String? board, String? tag, String? sort}) async => const [],
        ),
        communitySearchProvider.overrideWithValue(({
          required String q,
          String? board,
          String? tag,
          bool? solved,
          String? sort,
          int page = 0,
          int size = 20,
        }) async {
          searched.add((q, board));
          return const CommunitySearchResult(items: [], total: 0);
        }),
      ],
    );
    addTearDown(c.dispose);
    final router = _router(initialLocation: '/community?board=FREE&q=flutter');
    await tester.pumpWidget(_host(c, router: router));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(_titleMenu));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MenuItemButton, 'Q/A'));
    await tester.pumpAndSettle();

    expect(
      router.routeInformationProvider.value.uri.toString(),
      '/community?board=QNA&q=flutter',
    );
    expect(searched, [('flutter', 'FREE'), ('flutter', 'QNA')]);
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

  testWidgets('피드 행이 DpListRow로 렌더된다', (tester) async {
    final c = _container([_p(1, title: 'DpListRow 행', boardType: 'FREE')]);
    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();

    expect(find.byType(DpListRow), findsOneWidget);
    expect(find.text('DpListRow 행'), findsOneWidget);
  });
}
