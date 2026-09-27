import 'package:devpath_web/src/features/community/data/community_source.dart';
import 'package:devpath_web/src/features/community/presentation/qna_related_panel.dart';
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host({
  required SimilarQuestionsFetch fetch,
  int questionId = 1,
  String title = 'async/await가 헷갈려요',
}) => ProviderScope(
  overrides: [similarQuestionsProvider.overrideWithValue(fetch)],
  child: MaterialApp(
    theme: DpTheme.light(),
    home: Scaffold(
      body: QnaRelatedPanel(questionId: questionId, title: title),
    ),
  ),
);

void main() {
  testWidgets('QnaRelatedPanel: 관련 질문을 목록으로 그리고 자기 자신은 뺀다', (tester) async {
    await tester.pumpWidget(
      _host(
        fetch: (q) async => const [
          SimilarQuestion(questionId: 1, title: '자기 자신'),
          SimilarQuestion(questionId: 2, title: 'Stream 구독 해제는?'),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('관련 질문'), findsOneWidget);
    expect(find.text('Stream 구독 해제는?'), findsOneWidget);
    expect(find.text('자기 자신'), findsNothing);
  });

  testWidgets('QnaRelatedPanel: 질문 제목으로 조회한다', (tester) async {
    String? asked;
    await tester.pumpWidget(
      _host(
        fetch: (q) async {
          asked = q;
          return const [SimilarQuestion(questionId: 2, title: '다른 질문')];
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(asked, 'async/await가 헷갈려요');
  });

  testWidgets('QnaRelatedPanel: 결과가 자기 자신뿐이면 아무것도 그리지 않는다', (tester) async {
    await tester.pumpWidget(
      _host(
        fetch: (q) async => const [
          SimilarQuestion(questionId: 1, title: '자기 자신'),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('관련 질문'), findsNothing);
  });

  testWidgets('QnaRelatedPanel: 조회가 실패하면 조용히 사라진다', (tester) async {
    await tester.pumpWidget(_host(fetch: (q) async => throw Exception('boom')));
    await tester.pumpAndSettle();

    // 보조 정보다 — 실패가 본문 읽기를 막지 않는다.
    expect(find.text('관련 질문'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
