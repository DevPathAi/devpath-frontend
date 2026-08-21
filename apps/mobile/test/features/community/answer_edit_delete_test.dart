import 'package:devpath_mobile/src/features/auth/application/auth_controller.dart';
import 'package:devpath_mobile/src/features/community/application/qna_detail_controller.dart';
import 'package:devpath_mobile/src/features/community/data/community_source.dart';
import 'package:devpath_mobile/src/features/community/state/qna_detail_state.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('updateAnswer: 수정 후 상세를 재조회해 본문을 반영한다', () async {
    var calls = 0;
    final c = ProviderContainer(
      overrides: [
        // 컨트롤러가 build 에서 currentOwnerKeyProvider 를 읽는다 — 막지 않으면
        // 실제 인증 스택을 타고 죽는다(mobile 전용 제약).
        currentOwnerKeyProvider.overrideWithValue('owner-test'),
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

    final s = c.read(qnaDetailControllerProvider) as QnaLoaded;
    expect(s.detail.answers.single.bodyMd, '고친답변');
  });

  test('updateAnswer: 빈 본문이면 서버를 부르지 않는다', () async {
    var called = false;
    final c = ProviderContainer(
      overrides: [
        // 컨트롤러가 build 에서 currentOwnerKeyProvider 를 읽는다 — 막지 않으면
        // 실제 인증 스택을 타고 죽는다(mobile 전용 제약).
        currentOwnerKeyProvider.overrideWithValue('owner-test'),
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

  test('deleteAnswer: 삭제 후 상세를 재조회한다', () async {
    var deletedId = 0;
    var fetches = 0;
    final c = ProviderContainer(
      overrides: [
        // 컨트롤러가 build 에서 currentOwnerKeyProvider 를 읽는다 — 막지 않으면
        // 실제 인증 스택을 타고 죽는다(mobile 전용 제약).
        currentOwnerKeyProvider.overrideWithValue('owner-test'),
        qnaDetailFetchProvider.overrideWithValue((id) async {
          fetches++;
          return const CommunityQuestionDetail(id: 3, title: 'q', bodyMd: 'b');
        }),
        answerDeleteProvider.overrideWithValue((id) async => deletedId = id),
      ],
    );
    addTearDown(c.dispose);

    final n = c.read(qnaDetailControllerProvider.notifier);
    await n.load(3);
    await n.deleteAnswer(11);

    expect(deletedId, 11);
    // 이름이 주장하는 그것 — delete 호출만 세면 재조회를 지워도 green 이었다.
    expect(fetches, 2, reason: 'load 1회 + 삭제 후 재조회 1회');
  });

  test('deleteAnswer: 409 는 채택 해제 안내를 담는다 — 웹과 같은 문자열', () async {
    final c = ProviderContainer(
      overrides: [
        // 컨트롤러가 build 에서 currentOwnerKeyProvider 를 읽는다 — 막지 않으면
        // 실제 인증 스택을 타고 죽는다(mobile 전용 제약).
        currentOwnerKeyProvider.overrideWithValue('owner-test'),
        qnaDetailFetchProvider.overrideWithValue(
          (id) async =>
              const CommunityQuestionDetail(id: 3, title: 'q', bodyMd: 'b'),
        ),
        answerDeleteProvider.overrideWithValue(
          (id) async => throw const ApiException(
            code: ApiErrorCode.conflict,
            message: 'accepted',
          ),
        ),
      ],
    );
    addTearDown(c.dispose);

    final n = c.read(qnaDetailControllerProvider.notifier);
    await n.load(3);
    await n.deleteAnswer(11);

    final s = c.read(qnaDetailControllerProvider) as QnaLoaded;
    expect(s.actionError, '채택된 답변은 채택을 먼저 해제해 주세요');
  });

  test('updateAnswer: 403 은 전용 문구를 담는다', () async {
    final c = ProviderContainer(
      overrides: [
        // 컨트롤러가 build 에서 currentOwnerKeyProvider 를 읽는다 — 막지 않으면
        // 실제 인증 스택을 타고 죽는다(mobile 전용 제약).
        currentOwnerKeyProvider.overrideWithValue('owner-test'),
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
}
