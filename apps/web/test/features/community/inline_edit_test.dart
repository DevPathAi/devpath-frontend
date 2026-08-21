import 'package:devpath_web/src/features/community/application/post_detail_controller.dart';
import 'package:devpath_web/src/features/community/application/qna_detail_controller.dart';
import 'package:devpath_web/src/features/community/data/community_source.dart';
import 'package:devpath_web/src/features/community/state/qna_detail_state.dart';
import 'package:devpath_web/src/features/auth/application/auth_controller.dart';
import 'package:devpath_web/src/features/auth/state/auth_state.dart';
import 'package:devpath_web/src/features/community/data/lcs_source.dart';
import 'package:devpath_web/src/features/community/presentation/qna_detail_page.dart';
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('updateAnswer: 수정 후 상세를 재조회해 본문을 반영한다', () async {
    var calls = 0;
    final c = ProviderContainer(
      overrides: [
        qnaDetailFetchProvider.overrideWithValue((id) async {
          calls++;
          return CommunityQuestionDetail(
            id: 3,
            title: 'q',
            bodyMd: 'b',
            answers: [
              CommunityAnswer(id: 11, bodyMd: calls >= 2 ? '고친답변' : '원답변'),
            ],
          );
        }),
        answerUpdateProvider.overrideWithValue(
          (id, bodyMd) async => CommunityAnswer(id: id, bodyMd: bodyMd),
        ),
      ],
    );
    addTearDown(c.dispose);

    final n = c.read(qnaDetailControllerProvider.notifier);
    await n.load(3);
    await n.updateAnswer(11, '고친답변');

    final s = c.read(qnaDetailControllerProvider);
    expect(s, isA<QnaLoaded>());
    expect((s as QnaLoaded).detail.answers.single.bodyMd, '고친답변');
  });

  test('updateAnswer: 빈 본문이면 서버를 부르지 않는다', () async {
    var called = false;
    final c = ProviderContainer(
      overrides: [
        qnaDetailFetchProvider.overrideWithValue(
          (id) async =>
              const CommunityQuestionDetail(id: 3, title: 'q', bodyMd: 'b'),
        ),
        answerUpdateProvider.overrideWithValue((id, bodyMd) async {
          called = true;
          return CommunityAnswer(id: id, bodyMd: bodyMd);
        }),
      ],
    );
    addTearDown(c.dispose);

    final n = c.read(qnaDetailControllerProvider.notifier);
    await n.load(3);
    await n.updateAnswer(11, '   ');

    expect(called, isFalse);
  });

  test('updateAnswer: 403 은 전용 문구를 actionError 에 담는다', () async {
    final c = ProviderContainer(
      overrides: [
        qnaDetailFetchProvider.overrideWithValue(
          (id) async =>
              const CommunityQuestionDetail(id: 3, title: 'q', bodyMd: 'b'),
        ),
        answerUpdateProvider.overrideWithValue(
          (id, bodyMd) async => throw const ApiException(
            code: ApiErrorCode.forbidden,
            message: 'nope',
          ),
        ),
      ],
    );
    addTearDown(c.dispose);

    final n = c.read(qnaDetailControllerProvider.notifier);
    await n.load(3);
    await n.updateAnswer(11, '고친답변');

    final s = c.read(qnaDetailControllerProvider) as QnaLoaded;
    expect(s.actionError, '내가 쓴 글만 수정할 수 있어요');
  });

  test('updateComment: 수정 후 상세를 재조회해 본문을 반영한다', () async {
    var calls = 0;
    final c = ProviderContainer(
      overrides: [
        postDetailFetchProvider.overrideWithValue((id) async {
          calls++;
          return CommunityPostDetail(
            id: 9,
            boardType: 'FREE',
            title: 't',
            bodyMd: 'b',
            comments: [
              CommunityComment(
                id: 21,
                bodyMd: calls >= 2 ? '고친댓글' : '원댓글',
                createdAt: 'x',
              ),
            ],
          );
        }),
        commentUpdateProvider.overrideWithValue(
          (id, bodyMd) async =>
              CommunityComment(id: id, bodyMd: bodyMd, createdAt: 'x'),
        ),
      ],
    );
    addTearDown(c.dispose);

    final n = c.read(postDetailControllerProvider(9).notifier);
    await n.load();
    await n.updateComment(21, '고친댓글');

    expect(
      c.read(postDetailControllerProvider(9)).detail?.comments.single.bodyMd,
      '고친댓글',
    );
  });

  test('updateComment: 403 은 전용 문구를 error 에 담는다', () async {
    final c = ProviderContainer(
      overrides: [
        postDetailFetchProvider.overrideWithValue(
          (id) async => const CommunityPostDetail(
            id: 9,
            boardType: 'FREE',
            title: 't',
            bodyMd: 'b',
          ),
        ),
        commentUpdateProvider.overrideWithValue(
          (id, bodyMd) async => throw const ApiException(
            code: ApiErrorCode.forbidden,
            message: 'nope',
          ),
        ),
      ],
    );
    addTearDown(c.dispose);

    final n = c.read(postDetailControllerProvider(9).notifier);
    await n.load();
    await n.updateComment(21, '고친댓글');

    expect(c.read(postDetailControllerProvider(9)).error, '내가 쓴 글만 수정할 수 있어요');
  });

  testWidgets('내 답변 카드에서 수정을 누르면 편집 필드가 열린다', (tester) async {
    final c = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(_MineAuthController.new),
        qnaDetailFetchProvider.overrideWithValue(
          (id) async => const CommunityQuestionDetail(
            id: 1,
            title: 'q',
            bodyMd: 'b',
            // 질문은 남의 것이다 — 답변 메뉴만 「내 것」이 되게 해 구분을 만든다.
            authorId: 99,
            answers: [CommunityAnswer(id: 11, authorId: 7, bodyMd: '내 답변')],
          ),
        ),
        // 이 페이지는 LCS 스냅샷도 부른다. 막지 않으면 실제 HTTP 로 나간다.
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

    // 화면에 메뉴가 둘이다(질문 헤더 + 답변 카드). 답변 것은 뒤에 온다.
    await tester.tap(find.byKey(const ValueKey('content-menu')).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('수정하기'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('answer-edit-field')), findsOneWidget);
  });
}

/// 답변 작성자(7)와 같은 사용자로 로그인한 상태 — _isMine 을 참으로 만든다.
/// router_diagnostic_handoff_test.dart 의 _DoneAuthController 와 같은 패턴이다.
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
