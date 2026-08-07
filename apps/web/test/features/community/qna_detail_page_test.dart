import 'dart:async';

import 'package:devpath_web/src/features/community/data/community_source.dart';
import 'package:devpath_web/src/features/community/data/lcs_source.dart';
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
  List<String> tags = const [],
}) => CommunityQuestionDetail(
  id: 1,
  title: 'async 질문',
  bodyMd: '본문입니다',
  solved: solved,
  answers: answers,
  tags: tags,
);

LcsSnapshotView _snap() => LcsSnapshotView(
  id: 7,
  createdAt: DateTime(2026, 6, 26),
  content: const {
    'current_content': {'title': '비동기 기초', 'track': 'BACKEND'},
  },
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
        lcsByQuestionProvider.overrideWithValue((qid) async => null),
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
    expect(tester.widget<DpPageHeader>(find.byType(DpPageHeader)).title, 'Q&A');
  });

  // 3-A 최종 리뷰 I-1: 게시글 상세(post_detail_page.dart)는 DpTag를 쓰는데 이 화면만
  // Material Chip으로 남아 **형제 화면끼리 태그 칩 색이 갈려 있었다**(스펙 §7.1의
  // 배선 후보 조사에서 이 한 곳이 누락됐다). DpTag가 tag* 토큰의 유일한 배선
  // 지점이라는 선언을 실제로 성립시킨다 — Chip으로 되돌리면 red다.
  testWidgets('태그는 DpTag로 렌더된다 (게시글 상세와 같은 배선)', (tester) async {
    final c = ProviderContainer(
      overrides: [
        qnaDetailFetchProvider.overrideWithValue(
          (id) async =>
              _detail(answers: [_ans(11)], tags: const ['dart', 'async']),
        ),
        lcsByQuestionProvider.overrideWithValue((qid) async => null),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();

    expect(find.byType(DpTag), findsNWidgets(2));
    expect(find.byType(Chip), findsNothing);
    expect(find.text('#dart'), findsOneWidget);
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
        lcsByQuestionProvider.overrideWithValue((qid) async => null),
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
        lcsByQuestionProvider.overrideWithValue((qid) async => null),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '새 답변입니다');
    // 답변 등록 버튼은 목록 아래에 있어 뷰포트(600px) 경계에 걸린다. 카드에 위젯이
    // 하나만 늘어도 화면 밖으로 밀려 tap 이 빗나가므로 명시적으로 스크롤한다.
    final submit = find.widgetWithText(FilledButton, '답변 등록');
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(seenBody, '새 답변입니다');
    expect(fetchCalls, 2); // 작성 후 재조회
  });

  testWidgets('답변자 맥락 패널: 스냅샷 있으면 표시', (tester) async {
    final c = ProviderContainer(
      overrides: [
        qnaDetailFetchProvider.overrideWithValue(
          (id) async => _detail(answers: [_ans(11)]),
        ),
        lcsByQuestionProvider.overrideWithValue((qid) async => _snap()),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();

    expect(find.text('📚 작성자 학습 맥락'), findsOneWidget);
    expect(find.text('현재 콘텐츠'), findsOneWidget); // content 키 → 라벨 칩
  });

  testWidgets('답변자 맥락 패널: 스냅샷 없으면(null) 미표시', (tester) async {
    final c = ProviderContainer(
      overrides: [
        qnaDetailFetchProvider.overrideWithValue(
          (id) async => _detail(answers: [_ans(11)]),
        ),
        lcsByQuestionProvider.overrideWithValue((qid) async => null),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();

    expect(find.text('📚 작성자 학습 맥락'), findsNothing);
  });

  // 아래 두 건은 sliver 전환(Task 11)이 만든 로딩·실패 분기를 잠근다. 전환 전에는
  // Expanded(child: ...)라 레이아웃이 자명했지만 지금은 SliverFillRemaining이라
  // 헤더와 같은 스크롤 표면 위에서 렌더된다.
  testWidgets('로딩 중에도 헤더와 로딩 표시가 함께 렌더된다', (tester) async {
    final completer = Completer<CommunityQuestionDetail>();
    final c = ProviderContainer(
      overrides: [
        qnaDetailFetchProvider.overrideWithValue((id) => completer.future),
        lcsByQuestionProvider.overrideWithValue((qid) async => null),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(_host(c));
    await tester.pump(); // load() 시작 → QnaLoading

    expect(tester.widget<DpPageHeader>(find.byType(DpPageHeader)).title, 'Q&A');
    expect(find.byType(DpLoading), findsOneWidget);

    completer.complete(_detail(answers: const []));
    await tester.pumpAndSettle();
    expect(find.text('async 질문'), findsOneWidget);
  });

  testWidgets('조회 실패 시 헤더와 에러 안내가 함께 렌더된다', (tester) async {
    final c = ProviderContainer(
      overrides: [
        qnaDetailFetchProvider.overrideWithValue(
          (id) async => throw const ApiException(
            code: ApiErrorCode.unknown,
            message: '질문을 불러오지 못했어요',
          ),
        ),
        lcsByQuestionProvider.overrideWithValue((qid) async => null),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();

    expect(tester.widget<DpPageHeader>(find.byType(DpPageHeader)).title, 'Q&A');
    expect(find.textContaining('질문을 불러오지 못했어요'), findsWidgets);
  });
}
