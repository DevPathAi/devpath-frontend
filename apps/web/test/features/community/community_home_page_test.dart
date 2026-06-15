import 'package:devpath_web/src/features/community/data/community_source.dart';
import 'package:devpath_web/src/features/community/presentation/community_home_page.dart';
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart' hide Page; // dp_core Page<T>와 충돌 회피
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Widget _host(ProviderContainer c) {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const CommunityHomePage()),
      GoRoute(path: '/community/:id', builder: (_, _) => const SizedBox()),
    ],
  );
  return UncontrolledProviderScope(
    container: c,
    child: MaterialApp.router(theme: DpTheme.light(), routerConfig: router),
  );
}

void main() {
  testWidgets('목록을 렌더한다', (tester) async {
    final c = ProviderContainer(
      overrides: [
        communityFetchProvider.overrideWithValue(
          ({String? cursor}) async => Page(
            data: [CommunityPost(id: 'q1', title: 'async 질문', author: '지수')],
            limit: 20,
          ),
        ),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();
    expect(find.text('async 질문'), findsOneWidget);
  });

  testWidgets('빈 목록은 작성 CTA를 보인다', (tester) async {
    final c = ProviderContainer(
      overrides: [
        communityFetchProvider.overrideWithValue(
          ({String? cursor}) async => const Page(data: [], limit: 20),
        ),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();
    expect(find.textContaining('첫 질문'), findsOneWidget);
  });

  // 🔶 ENG-REVIEW(§9.2 ERROR): 첫 로드 실패 → DpError + 재시도 탭 → reload.
  testWidgets('첫 로드 실패는 DpError와 재시도를 보인다', (tester) async {
    var calls = 0;
    final c = ProviderContainer(
      overrides: [
        communityFetchProvider.overrideWithValue(({String? cursor}) async {
          calls++;
          if (calls == 1) {
            throw const ApiException(
              code: ApiErrorCode.network,
              message: '네트워크 오류',
            );
          }
          return Page(
            data: [CommunityPost(id: 'q1', title: '복구된 글', author: '지수')],
            limit: 20,
          );
        }),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();
    expect(find.byType(DpError), findsOneWidget);

    await tester.tap(find.text('다시 시도')); // DpError 재시도
    await tester.pumpAndSettle();
    expect(find.text('복구된 글'), findsOneWidget); // reload 성공
  });

  // 🔶 ENG-REVIEW(더 보기 상호작용): hasMore=true → 버튼 렌더+탭 → 2페이지 누적(PARTIAL).
  testWidgets('"더 보기" 탭은 다음 페이지를 누적한다', (tester) async {
    final c = ProviderContainer(
      overrides: [
        communityFetchProvider.overrideWithValue(({String? cursor}) async {
          if (cursor == null) {
            return Page(
              data: [CommunityPost(id: 'q1', title: '1페이지글', author: '지수')],
              nextCursor: 'c2',
              limit: 20,
            );
          }
          return Page(
            data: [CommunityPost(id: 'q2', title: '2페이지글', author: '민준')],
            limit: 20,
          );
        }),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();
    expect(find.text('더 보기'), findsOneWidget); // hasMore → 버튼 렌더

    await tester.tap(find.text('더 보기'));
    await tester.pumpAndSettle();
    expect(find.text('1페이지글'), findsOneWidget);
    expect(find.text('2페이지글'), findsOneWidget); // 누적
    expect(find.text('더 보기'), findsNothing); // nextCursor null → 버튼 사라짐
  });

  // 🔶 ENG-REVIEW(P2 loadMore 에러): 더 보기 실패가 무음이면 안 됨 → 인라인 에러 표시.
  testWidgets('"더 보기" 실패는 인라인 에러를 보인다(무음 금지)', (tester) async {
    final c = ProviderContainer(
      overrides: [
        communityFetchProvider.overrideWithValue(({String? cursor}) async {
          if (cursor == null) {
            return Page(
              data: [CommunityPost(id: 'q1', title: '1페이지글', author: '지수')],
              nextCursor: 'c2',
              limit: 20,
            );
          }
          throw const ApiException(
            code: ApiErrorCode.network,
            message: '더 보기 실패',
          );
        }),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();

    await tester.tap(find.text('더 보기'));
    await tester.pumpAndSettle();
    // 기존 목록은 유지하면서 에러를 노출(인라인 텍스트 또는 SnackBar)
    expect(find.text('1페이지글'), findsOneWidget);
    expect(find.textContaining('더 보기 실패'), findsWidgets);
    expect(find.text('재시도'), findsOneWidget); // 인라인 재시도
  });
}
