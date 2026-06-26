import 'package:devpath_web/src/features/community/data/community_source.dart';
import 'package:devpath_web/src/features/community/presentation/qna_detail_page.dart';
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

CommunityAnswer _ans(
  int id, {
  bool accepted = false,
  bool ai = false,
  String body = '답변',
}) => CommunityAnswer(
  id: id,
  authorId: ai ? null : 7,
  bodyMd: body,
  aiGenerated: ai,
  accepted: accepted,
);

CommunityQuestionDetail _detail({
  bool solved = false,
  required List<CommunityAnswer> answers,
}) => CommunityQuestionDetail(
  id: 1,
  title: 'async 질문',
  bodyMd: '본문입니다',
  solved: solved,
  answers: answers,
);

Widget _host(ProviderContainer c) => UncontrolledProviderScope(
  container: c,
  child: MaterialApp(
    theme: DpTheme.light(),
    home: const QnaDetailPage(postId: '1'),
  ),
);

void main() {
  testWidgets('상세: 제목·본문·AI 초안 뱃지·채택됨 표시', (tester) async {
    final c = ProviderContainer(
      overrides: [
        qnaDetailFetchProvider.overrideWithValue(
          (id) async => _detail(
            solved: true,
            answers: [
              _ans(10, ai: true, body: 'AI 초안 답변'),
              _ans(11, accepted: true, body: '사람 답변'),
            ],
          ),
        ),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();

    expect(find.text('async 질문'), findsOneWidget);
    expect(find.textContaining('본문입니다'), findsWidgets);
    expect(find.text('🤖 AI 초안'), findsOneWidget); // AI 뱃지
    expect(find.text('채택됨'), findsOneWidget); // 채택된 답변
    // 이미 solved → 채택 버튼 없음
    expect(find.widgetWithText(TextButton, '채택'), findsNothing);
  });

  testWidgets('미해결 질문: 미채택 답변에 채택 버튼 노출 + 탭 시 채택 호출', (tester) async {
    var fetchCalls = 0;
    int? acceptedId;
    final c = ProviderContainer(
      overrides: [
        qnaDetailFetchProvider.overrideWithValue((id) async {
          fetchCalls++;
          return fetchCalls == 1
              ? _detail(answers: [_ans(11)])
              : _detail(solved: true, answers: [_ans(11, accepted: true)]);
        }),
        answerAcceptProvider.overrideWithValue((id) async => acceptedId = id),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();

    final acceptBtn = find.widgetWithText(TextButton, '채택');
    expect(acceptBtn, findsOneWidget);

    await tester.tap(acceptBtn);
    await tester.pumpAndSettle();
    expect(acceptedId, 11);
    // 재조회로 solved → 버튼 사라지고 '채택됨' 표시
    expect(find.widgetWithText(TextButton, '채택'), findsNothing);
    expect(find.text('채택됨'), findsOneWidget);
  });

  testWidgets('답변 등록 버튼은 작성 시 submitAnswer를 호출한다', (tester) async {
    var fetchCalls = 0;
    String? seenBody;
    final c = ProviderContainer(
      overrides: [
        qnaDetailFetchProvider.overrideWithValue((id) async {
          fetchCalls++;
          return _detail(answers: [_ans(11)]);
        }),
        answerCreateProvider.overrideWithValue((qid, body) async {
          seenBody = body;
          return _ans(12);
        }),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '새 답변입니다');
    await tester.tap(find.widgetWithText(FilledButton, '답변 등록'));
    await tester.pumpAndSettle();

    expect(seenBody, '새 답변입니다');
    expect(fetchCalls, 2); // 작성 후 재조회
  });
}
