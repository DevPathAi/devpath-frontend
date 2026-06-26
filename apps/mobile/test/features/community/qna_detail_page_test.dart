import 'package:devpath_mobile/src/features/community/presentation/qna_detail_page.dart';
import 'package:devpath_mobile/src/providers/api_providers.dart';
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/mock_api.dart';

final Map<String, MockFixture> _fx = {
  'GET /community/questions/1': (
    200,
    {
      'id': 1,
      'title': 'async 질문',
      'bodyMd': '본문 내용',
      'solved': false,
      'acceptedAnswerId': null,
      'upvoteCount': 2,
      'downvoteCount': 0,
      'tags': ['dart', 'async'],
      'answers': [
        {
          'id': 11,
          'authorId': null,
          'bodyMd': 'AI가 제안한 답변',
          'aiGenerated': true,
          'accepted': false,
          'upvoteCount': 1,
        },
      ],
    },
  ),
  'POST /community/questions/1/answers': (
    201,
    {
      'id': 12,
      'authorId': 7,
      'bodyMd': '새 답변',
      'aiGenerated': false,
      'accepted': false,
      'upvoteCount': 0,
    },
  ),
  'POST /community/answers/11/accept': (200, <String, dynamic>{}),
  'POST /community/posts/1/vote': (200, <String, dynamic>{}),
  'POST /community/answers/11/vote': (200, <String, dynamic>{}),
};

Widget _host(ProviderContainer c) => UncontrolledProviderScope(
  container: c,
  child: MaterialApp(
    theme: DpTheme.light(),
    home: const QnaDetailPage(postId: '1'),
  ),
);

ProviderContainer _container(Map<String, MockFixture> fx) {
  final c = ProviderContainer(
    overrides: [apiClientProvider.overrideWithValue(mockApiClient(fx))],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  testWidgets('상세 로드 → 제목·답변 수·AI 배지·채택 버튼 렌더', (tester) async {
    await tester.pumpWidget(_host(_container(_fx)));
    await tester.pumpAndSettle();

    expect(find.text('async 질문'), findsOneWidget);
    expect(find.text('답변 1'), findsOneWidget);
    expect(find.text('🤖 AI 초안'), findsOneWidget);
    // 미해결 + 미채택 답변 → 채택 버튼 노출.
    expect(find.text('채택'), findsOneWidget);
  });

  testWidgets('답변 입력 + 등록 → 크래시 없이 재조회', (tester) async {
    await tester.pumpWidget(_host(_container(_fx)));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '새 답변입니다');
    await tester.tap(find.text('답변 등록'));
    await tester.pumpAndSettle();

    expect(find.text('async 질문'), findsOneWidget);
  });

  testWidgets('추천 버튼 탭 → 투표 처리(상세 유지)', (tester) async {
    await tester.pumpWidget(_host(_container(_fx)));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('추천').first);
    await tester.pumpAndSettle();

    expect(find.text('async 질문'), findsOneWidget);
  });
}
