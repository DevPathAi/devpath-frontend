import 'package:devpath_web/src/features/auth/application/auth_controller.dart';
import 'package:devpath_web/src/features/auth/state/auth_state.dart';
import 'package:devpath_web/src/features/community/application/qna_detail_controller.dart';
import 'package:devpath_web/src/features/community/data/community_source.dart';
import 'package:devpath_web/src/features/community/data/lcs_source.dart';
import 'package:devpath_web/src/features/community/presentation/qna_detail_page.dart';
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 인라인 에디터의 stale 본문 계약. `late final TextEditingController` 는 카드가 처음
/// 만들어질 때의 본문을 쥔다 — 재조회로 본문이 바뀐 뒤 에디터를 열면 옛 본문이 뜨고,
/// 그대로 저장하면 최신을 덮는다. 대표 자리(web 답변)에 계약을 세우고 같은 수정을
/// web 댓글·mobile 답변에 적용한다(세 곳이 문자 그대로 같은 패턴이다).
class _MineAuthController extends AuthController {
  @override
  AuthState build() => const AuthAuthenticated(
    User(
      id: '7',
      email: 'me@example.com',
      nickname: '나',
      role: UserRole.learner,
      onboardingStatus: OnboardingStatus.done,
      consentStatus: ConsentStatus.done,
    ),
  );
}

void main() {
  testWidgets('재조회로 본문이 바뀐 뒤 편집을 열면 새 본문이 보인다', (tester) async {
    var body = '원답변';
    final c = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(_MineAuthController.new),
        qnaDetailFetchProvider.overrideWithValue(
          (id) async => CommunityQuestionDetail(
            id: 1,
            title: 'q',
            bodyMd: 'b',
            answers: [CommunityAnswer(id: 11, authorId: 7, bodyMd: body)],
          ),
        ),
        lcsByQuestionProvider.overrideWithValue((qid) async => null),
        communityVoteProvider.overrideWithValue(
          ({required target, required id, required value}) async {},
        ),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          theme: DpTheme.light(),
          home: const QnaDetailPage(postId: '1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('원답변'), findsWidgets);

    // ★결함 창을 정확히 밟는다 — 두 번 좁혀진 시나리오다★
    // ① load() 재조회는 QnaLoading 을 거치며 카드 서브트리를 폐기해 late final 이 새로
    //    초기화된다(스테일 없음, 실측). ② 한 번도 안 연 에디터도 스테일이 없다 — late 는
    //    첫 접근 때 그 시점의 widget.answer 로 초기화된다(실측). 남는 창은:
    //    "열었다 닫은 뒤" QnaLoaded 가 유지되는 _mutate 재조회(투표)로 본문이 바뀌고
    //    "다시 열 때" 다.
    // 질문 헤더에도 같은 키의 메뉴가 있다 — 답변 카드 것(뒤쪽)을 집는다.
    await tester.tap(find.byKey(const ValueKey('content-menu')).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('수정하기'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('answer-edit-cancel')));
    await tester.pumpAndSettle();

    body = '고친답변';
    await c
        .read(qnaDetailControllerProvider.notifier)
        .vote(CommunityVoteTarget.answer, 11, 1);
    await tester.pumpAndSettle();
    expect(find.textContaining('고친답변'), findsWidgets, reason: '카드는 새 본문을 그린다');

    await tester.tap(find.byKey(const ValueKey('content-menu')).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('수정하기'));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('answer-edit-field')),
    );
    expect(
      field.controller!.text,
      '고친답변',
      reason:
          'late final 컨트롤러가 옛 본문을 쥐고 있으면 여기가 원답변이다 — '
          '그대로 저장하면 최신을 덮는다',
    );
  });

  testWidgets('저장이 실패하면 에디터와 입력이 유지된다', (tester) async {
    final c = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(_MineAuthController.new),
        qnaDetailFetchProvider.overrideWithValue(
          (id) async => const CommunityQuestionDetail(
            id: 1,
            title: 'q',
            bodyMd: 'b',
            answers: [CommunityAnswer(id: 11, authorId: 7, bodyMd: '원답변')],
          ),
        ),
        lcsByQuestionProvider.overrideWithValue((qid) async => null),
        answerUpdateProvider.overrideWithValue((id, bodyMd) async {
          throw const ApiException(
            code: ApiErrorCode.forbidden,
            message: 'nope',
          );
        }),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          theme: DpTheme.light(),
          home: const QnaDetailPage(postId: '1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('content-menu')).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('수정하기'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('answer-edit-field')),
      '한참 공들여 쓴 새 본문',
    );
    await tester.tap(find.byKey(const ValueKey('answer-edit-save')));
    await tester.pumpAndSettle();

    // ★실패했는데 에디터가 닫히면 입력이 사라진다★ — 재열기는 서버 본문으로 동기화하므로
    // (stale-body 계약) 닫는 순간 사용자가 쓴 것은 되찾을 수 없다.
    expect(
      find.byKey(const ValueKey('answer-edit-field')),
      findsOneWidget,
      reason: '실패 시 에디터를 유지한다',
    );
    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('answer-edit-field')),
    );
    expect(field.controller!.text, '한참 공들여 쓴 새 본문', reason: '입력이 보존된다');
    expect(
      find.text('내가 쓴 글만 수정할 수 있어요'),
      findsOneWidget,
      reason: '실패 사유가 표면화된다',
    );
  });

  testWidgets('빈 본문 저장은 안내를 띄우고 에디터를 유지한다', (tester) async {
    final c = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(_MineAuthController.new),
        qnaDetailFetchProvider.overrideWithValue(
          (id) async => const CommunityQuestionDetail(
            id: 1,
            title: 'q',
            bodyMd: 'b',
            answers: [CommunityAnswer(id: 11, authorId: 7, bodyMd: '원답변')],
          ),
        ),
        lcsByQuestionProvider.overrideWithValue((qid) async => null),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          theme: DpTheme.light(),
          home: const QnaDetailPage(postId: '1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('content-menu')).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('수정하기'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('answer-edit-field')),
      '   ',
    );
    await tester.tap(find.byKey(const ValueKey('answer-edit-save')));
    await tester.pump();

    // 컨트롤러는 빈 본문을 서버에 안 보낸다(왕복 낭비) — 그 침묵이 사용자에게는
    // "저장했는데 아무 일도 없다" 로 보였다. 스펙의 400 문구로 표면화한다.
    expect(
      find.text('내용을 입력해 주세요'),
      findsOneWidget,
      reason: '조용히 삼키면 아무 안내도 없다',
    );
    expect(
      find.byKey(const ValueKey('answer-edit-field')),
      findsOneWidget,
      reason: '실패했는데 에디터가 닫히면 입력이 사라진다',
    );
  });
}
