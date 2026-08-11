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
}) => CommunityPostSummary(
  id: id,
  title: title ?? '글 $id',
  boardType: boardType,
  solved: solved,
  replyCount: 1,
);

Widget _host(ProviderContainer c) {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const CommunityHomePage()),
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

void main() {
  testWidgets('목록을 렌더한다(작성자 이름 없이 메타 표시)', (tester) async {
    final c = ProviderContainer(
      overrides: [
        communityListProvider.overrideWithValue(
          ({String? board, String? tag, String? sort}) async => [
            _p(1, title: 'async 질문'),
          ],
        ),
      ],
    );
    addTearDown(c.dispose);
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

    final c = ProviderContainer(
      overrides: [
        communityListProvider.overrideWithValue(
          ({String? board, String? tag, String? sort}) async => [
            for (var i = 1; i <= 6; i++) _p(i),
          ],
        ),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();

    // 조건 성립 검산: 광고가 실제로 끼어든 상태인가(6 >= 임계 5).
    expect(find.byType(AdSlotWidget), findsOneWidget);

    final view = tester.widget<CustomScrollView>(find.byType(CustomScrollView));
    expect(view.semanticChildCount, 6);
  });

  testWidgets('빈 목록은 작성 CTA를 보인다', (tester) async {
    final c = ProviderContainer(
      overrides: [
        communityListProvider.overrideWithValue(
          ({String? board, String? tag, String? sort}) async => const [],
        ),
      ],
    );
    addTearDown(c.dispose);
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

  testWidgets('FAB 스피드다이얼 "질문하기"는 작성 화면으로 이동한다', (tester) async {
    final c = ProviderContainer(
      overrides: [
        communityListProvider.overrideWithValue(
          ({String? board, String? tag, String? sort}) async => [_p(1)],
        ),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('질문하기'));
    await tester.pumpAndSettle();
    expect(find.text('작성 화면'), findsOneWidget);
  });

  testWidgets('FAB 스피드다이얼 "자유글"은 일반 작성 화면으로 이동한다', (tester) async {
    final c = ProviderContainer(
      overrides: [
        communityListProvider.overrideWithValue(
          ({String? board, String? tag, String? sort}) async => [_p(1)],
        ),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('자유글'));
    await tester.pumpAndSettle();
    expect(find.text('일반 작성 화면'), findsOneWidget);
  });

  testWidgets('QNA 항목 탭은 Q&A 상세로 이동한다', (tester) async {
    final c = ProviderContainer(
      overrides: [
        communityListProvider.overrideWithValue(
          ({String? board, String? tag, String? sort}) async => [
            _p(7, title: '탭할 글'),
          ],
        ),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();

    await tester.tap(find.text('탭할 글'));
    await tester.pumpAndSettle();
    expect(find.text('상세 화면'), findsOneWidget);
  });

  testWidgets('통합 피드: 필터칩 4개 + 보드 뱃지 + 일반글 탭 라우팅', (tester) async {
    final c = ProviderContainer(
      overrides: [
        communityListProvider.overrideWithValue(
          ({String? board, String? tag, String? sort}) async => [
            _p(10, title: '자유글', boardType: 'FREE'),
          ],
        ),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();

    // 필터: SegmentedButton(전체/Q&A/자유/피드백)
    expect(find.byType(SegmentedButton<CommunityBoard>), findsOneWidget);
    expect(find.text('전체'), findsOneWidget);
    expect(find.text('Q&A'), findsOneWidget);
    expect(find.text('피드백'), findsOneWidget);
    // 카드 제목 + 보드 뱃지('자유')
    expect(find.text('자유글'), findsOneWidget);
    expect(find.text('자유'), findsWidgets); // 세그먼트 + 뱃지
    // subtitle: FREE는 "댓글" 라벨
    expect(find.textContaining('댓글 1'), findsOneWidget);

    // FREE 항목 탭 → 일반 상세 라우트
    await tester.tap(find.text('자유글'));
    await tester.pumpAndSettle();
    expect(find.text('일반 상세 화면'), findsOneWidget);
  });

  testWidgets('SegmentedButton 선택 시 selectBoard로 재조회한다', (tester) async {
    final seen = <String?>[];
    final c = ProviderContainer(
      overrides: [
        communityListProvider.overrideWithValue(({
          String? board,
          String? tag,
          String? sort,
        }) async {
          seen.add(board);
          return [_p(10, title: '질문글', boardType: 'QNA')];
        }),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();

    await tester.tap(find.text('자유')); // QNA post라 '자유'는 세그먼트뿐
    await tester.pumpAndSettle();
    expect(seen, contains('FREE'));
  });

  testWidgets('initialBoard 쿼리로 진입 시 초기 필터가 반영된다', (tester) async {
    final seen = <String?>[];
    final c = ProviderContainer(
      overrides: [
        communityListProvider.overrideWithValue(({
          String? board,
          String? tag,
          String? sort,
        }) async {
          seen.add(board);
          return const [];
        }),
      ],
    );
    addTearDown(c.dispose);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const CommunityHomePage(initialBoard: 'FREE'),
        ),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp.router(theme: DpTheme.light(), routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(seen, contains('FREE'));
  });

  testWidgets('피드 행이 DpListRow로 렌더된다', (tester) async {
    final c = ProviderContainer(
      overrides: [
        communityListProvider.overrideWithValue(
          ({String? board, String? tag, String? sort}) async => [
            _p(1, title: 'DpListRow 행', boardType: 'FREE'),
          ],
        ),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();

    expect(find.byType(DpListRow), findsOneWidget);
    expect(find.text('DpListRow 행'), findsOneWidget);
  });
}
