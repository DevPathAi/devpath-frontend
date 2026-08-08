import 'package:devpath_web/src/features/community/data/community_source.dart';
import 'package:devpath_web/src/features/community/presentation/community_home_page.dart';
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

CommunityPostSummary _p(int id) =>
    CommunityPostSummary(id: id, title: '목록 글 $id', replyCount: 1);

CommunitySearchItem _s(int id, {String? title, String highlight = ''}) =>
    CommunitySearchItem(
      id: id,
      title: title ?? '검색 결과 $id',
      highlight: highlight,
      replyCount: 1,
    );

/// 검색어가 없을 때 렌더될 기본 목록 + 검색 override.
/// (`Override` 타입은 flutter_riverpod 가 re-export 하지 않아 컨테이너째 만들어 돌려준다.)
ProviderContainer _containerWith({CommunitySearchFetch? search}) {
  final c = ProviderContainer(
    overrides: [
      communityListProvider.overrideWithValue(
        ({String? board, String? tag, String? sort}) async => [_p(1)],
      ),
      if (search != null) communitySearchProvider.overrideWithValue(search),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

Widget _host(ProviderContainer c, {String? initialQuery}) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => CommunityHomePage(initialQuery: initialQuery),
      ),
      // 검색어 변경 시 URL 을 갱신하므로 같은 페이지로 되돌아오는 라우트가 필요하다.
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
        builder: (_, _) => const Text('일반 작성 화면'),
      ),
      GoRoute(
        path: '/community/post/:id',
        builder: (_, _) => const Text('일반 상세 화면'),
      ),
      GoRoute(path: '/community/:id', builder: (_, _) => const Text('상세 화면')),
    ],
  );
  return UncontrolledProviderScope(
    container: c,
    child: MaterialApp.router(theme: DpTheme.light(), routerConfig: router),
  );
}

Finder get _searchField => find.byKey(const ValueKey('community-search-field'));

void main() {
  testWidgets('검색어 입력 → 400ms 디바운스 후에만 검색을 호출한다', (tester) async {
    final calls = <String>[];
    final c = _containerWith(
      search:
          ({
            required String q,
            String? board,
            String? tag,
            bool? solved,
            String? sort,
            int page = 0,
            int size = 20,
          }) async {
            calls.add(q);
            return CommunitySearchResult(items: [_s(1)], total: 1);
          },
    );
    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();

    await tester.enterText(_searchField, 'Riverpod');
    await tester.pump(const Duration(milliseconds: 300));
    expect(calls, isEmpty, reason: '디바운스가 끝나기 전에는 호출하지 않아야 한다');

    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpAndSettle();
    expect(calls, ['Riverpod']);
  });

  testWidgets('검색 결과를 목록 행으로 렌더한다', (tester) async {
    final c = _containerWith(
      search:
          ({
            required String q,
            String? board,
            String? tag,
            bool? solved,
            String? sort,
            int page = 0,
            int size = 20,
          }) async => CommunitySearchResult(
            items: [
              _s(1, title: '첫 결과'),
              _s(2, title: '둘째 결과'),
            ],
            total: 2,
          ),
    );
    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();

    await tester.enterText(_searchField, '검색어');
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();

    expect(find.text('첫 결과'), findsOneWidget);
    expect(find.text('둘째 결과'), findsOneWidget);
    expect(find.text('목록 글 1'), findsNothing, reason: '검색 중에는 기본 목록을 감춘다');
  });

  testWidgets('검색 결과의 semanticChildCount는 「더 보기」를 제외한 결과 수다', (tester) async {
    final c = _containerWith(
      search:
          ({
            required String q,
            String? board,
            String? tag,
            bool? solved,
            String? sort,
            int page = 0,
            int size = 20,
          }) async => CommunitySearchResult(
            items: [
              _s(1, title: '첫 결과'),
              _s(2, title: '둘째 결과'),
            ],
            // items(2) < total(5) → hasMore → itemCount에 「더 보기」가 하나 더 붙는다.
            total: 5,
          ),
    );
    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();

    await tester.enterText(_searchField, '검색어');
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();

    // 조건 성립 검산: 「더 보기」가 실제로 붙은 상태인가.
    expect(find.byKey(const ValueKey('search-more')), findsOneWidget);

    final view = tester.widget<CustomScrollView>(find.byType(CustomScrollView));
    expect(view.semanticChildCount, 2, reason: '버튼은 목록 항목이 아니다');
  });

  testWidgets('검색어를 지우면 기본 목록으로 돌아간다', (tester) async {
    var searchCalls = 0;
    final c = _containerWith(
      search:
          ({
            required String q,
            String? board,
            String? tag,
            bool? solved,
            String? sort,
            int page = 0,
            int size = 20,
          }) async {
            searchCalls++;
            return CommunitySearchResult(items: [_s(1)], total: 1);
          },
    );
    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();

    await tester.enterText(_searchField, '검색어');
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();
    expect(searchCalls, 1);

    await tester.enterText(_searchField, '');
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();

    expect(find.text('목록 글 1'), findsOneWidget);
    expect(searchCalls, 1, reason: '빈 검색어로는 서버를 부르지 않는다');
  });

  testWidgets('결과 0건이면 빈 결과 안내를 보여준다', (tester) async {
    final c = _containerWith(
      search:
          ({
            required String q,
            String? board,
            String? tag,
            bool? solved,
            String? sort,
            int page = 0,
            int size = 20,
          }) async => const CommunitySearchResult(),
    );
    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();

    await tester.enterText(_searchField, '없는검색어');
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('search-empty')), findsOneWidget);
    expect(find.byKey(const ValueKey('search-error')), findsNothing);
  });

  testWidgets('검색 실패 시 에러 위젯과 재시도 — 빈 결과와 구분된다', (tester) async {
    var attempts = 0;
    final c = _containerWith(
      search:
          ({
            required String q,
            String? board,
            String? tag,
            bool? solved,
            String? sort,
            int page = 0,
            int size = 20,
          }) async {
            attempts++;
            if (attempts == 1) {
              throw const ApiException(
                code: ApiErrorCode.unknown,
                message: '검색 서버 오류',
              );
            }
            return CommunitySearchResult(items: [_s(1)], total: 1);
          },
    );
    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();

    await tester.enterText(_searchField, '검색어');
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('search-error')), findsOneWidget);
    expect(find.byKey(const ValueKey('search-empty')), findsNothing);

    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.byKey(const ValueKey('search-error')), findsNothing);
    expect(find.text('검색 결과 1'), findsOneWidget);
  });

  testWidgets('total 이 더 크면 더 보기가 뜨고 다음 페이지를 이어붙인다', (tester) async {
    final pages = <int>[];
    final c = _containerWith(
      search:
          ({
            required String q,
            String? board,
            String? tag,
            bool? solved,
            String? sort,
            int page = 0,
            int size = 20,
          }) async {
            pages.add(page);
            return CommunitySearchResult(
              items: [_s(page * 10 + 1, title: '페이지$page 결과')],
              total: 3,
              page: page,
            );
          },
    );
    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();

    await tester.enterText(_searchField, '검색어');
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('search-more')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('search-more')));
    await tester.pumpAndSettle();

    expect(pages, [0, 1]);
    expect(find.text('페이지0 결과'), findsOneWidget, reason: '이전 결과를 유지해야 한다');
    expect(find.text('페이지1 결과'), findsOneWidget);
  });

  testWidgets('total 과 결과 수가 같으면 더 보기가 없다', (tester) async {
    final c = _containerWith(
      search:
          ({
            required String q,
            String? board,
            String? tag,
            bool? solved,
            String? sort,
            int page = 0,
            int size = 20,
          }) async => CommunitySearchResult(items: [_s(1), _s(2)], total: 2),
    );
    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();

    await tester.enterText(_searchField, '검색어');
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('search-more')), findsNothing);
  });

  testWidgets('?q= 로 진입하면 즉시 검색 결과를 보여준다', (tester) async {
    final calls = <String>[];
    final c = _containerWith(
      search:
          ({
            required String q,
            String? board,
            String? tag,
            bool? solved,
            String? sort,
            int page = 0,
            int size = 20,
          }) async {
            calls.add(q);
            return CommunitySearchResult(
              items: [_s(1, title: '딥링크 결과')],
              total: 1,
            );
          },
    );
    await tester.pumpWidget(_host(c, initialQuery: 'Riverpod'));
    await tester.pumpAndSettle();

    expect(calls, ['Riverpod']);
    expect(find.text('딥링크 결과'), findsOneWidget);
  });

  testWidgets('결과 행에 하이라이트가 표시되고 em 태그는 노출되지 않는다', (tester) async {
    final c = _containerWith(
      search:
          ({
            required String q,
            String? board,
            String? tag,
            bool? solved,
            String? sort,
            int page = 0,
            int size = 20,
          }) async => CommunitySearchResult(
            items: [_s(1, title: '결과', highlight: '본문에 <em>키워드</em>가 있다')],
            total: 1,
          ),
    );
    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();

    await tester.enterText(_searchField, '키워드');
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();

    expect(find.textContaining('키워드', findRichText: true), findsWidgets);
    expect(find.textContaining('<em>', findRichText: true), findsNothing);
  });
}
