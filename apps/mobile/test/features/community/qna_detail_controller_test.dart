import 'dart:async';

import 'package:devpath_mobile/src/features/auth/application/auth_controller.dart';
import 'package:devpath_mobile/src/features/community/application/qna_detail_controller.dart';
import 'package:devpath_mobile/src/features/community/data/community_source.dart';
import 'package:devpath_mobile/src/features/community/state/qna_detail_state.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

CommunityAnswer _ans(int id, {bool accepted = false, bool ai = false}) =>
    CommunityAnswer(
      id: id,
      bodyMd: 'a$id',
      accepted: accepted,
      aiGenerated: ai,
    );

CommunityQuestionDetail _detail({
  String title = 'Q',
  bool solved = false,
  List<CommunityAnswer> answers = const [],
}) => CommunityQuestionDetail(
  id: 1,
  title: title,
  bodyMd: 'B',
  solved: solved,
  answers: answers,
);

final _ownerProvider = NotifierProvider<_OwnerController, String?>(
  _OwnerController.new,
);

void main() {
  test('load: QnaLoaded(detail)', () async {
    final c = ProviderContainer(
      overrides: [
        qnaDetailFetchProvider.overrideWithValue(
          (id) async => _detail(answers: [_ans(11)]),
        ),
      ],
    );
    addTearDown(c.dispose);
    await c.read(qnaDetailControllerProvider.notifier).load(1);
    final s = c.read(qnaDetailControllerProvider);
    expect(s, isA<QnaLoaded>());
    expect((s as QnaLoaded).detail.answers, hasLength(1));
  });

  test('accept 성공: 채택 호출 후 상세 재조회로 solved 반영', () async {
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

    final n = c.read(qnaDetailControllerProvider.notifier);
    await n.load(1);
    await n.accept(11);

    expect(acceptedId, 11);
    expect(fetchCalls, 2);
    final s = c.read(qnaDetailControllerProvider) as QnaLoaded;
    expect(s.detail.solved, isTrue);
    expect(s.detail.answers.first.accepted, isTrue);
    expect(s.submitting, isFalse);
  });

  test('accept 403(비작성자): 상세 유지 + actionError 표면화', () async {
    final c = ProviderContainer(
      overrides: [
        qnaDetailFetchProvider.overrideWithValue(
          (id) async => _detail(answers: [_ans(11)]),
        ),
        answerAcceptProvider.overrideWithValue(
          (id) async => throw const ApiException(
            code: ApiErrorCode.forbidden,
            message: '질문 작성자만 채택할 수 있어요',
          ),
        ),
      ],
    );
    addTearDown(c.dispose);

    final n = c.read(qnaDetailControllerProvider.notifier);
    await n.load(1);
    await n.accept(11);

    final s = c.read(qnaDetailControllerProvider) as QnaLoaded;
    expect(s.actionError, '질문 작성자만 채택할 수 있어요');
    expect(s.detail.solved, isFalse);
    expect(s.submitting, isFalse);
  });

  test('vote: 대상/값을 데이터 레이어로 전달 후 재조회', () async {
    var fetchCalls = 0;
    CommunityVoteTarget? seenTarget;
    int? seenId, seenValue;
    final c = ProviderContainer(
      overrides: [
        qnaDetailFetchProvider.overrideWithValue((id) async {
          fetchCalls++;
          return _detail(answers: [_ans(11)]);
        }),
        communityVoteProvider.overrideWithValue(({
          required CommunityVoteTarget target,
          required int id,
          required int value,
        }) async {
          seenTarget = target;
          seenId = id;
          seenValue = value;
        }),
      ],
    );
    addTearDown(c.dispose);

    final n = c.read(qnaDetailControllerProvider.notifier);
    await n.load(1);
    await n.vote(CommunityVoteTarget.answer, 11, 1);

    expect(seenTarget, CommunityVoteTarget.answer);
    expect(seenId, 11);
    expect(seenValue, 1);
    expect(fetchCalls, 2);
  });

  test('submitAnswer: 본문 전달 + 재조회로 스레드 갱신', () async {
    var fetchCalls = 0;
    String? seenBody;
    final c = ProviderContainer(
      overrides: [
        qnaDetailFetchProvider.overrideWithValue((id) async {
          fetchCalls++;
          return fetchCalls == 1
              ? _detail(answers: [_ans(11)])
              : _detail(answers: [_ans(11), _ans(12)]);
        }),
        answerCreateProvider.overrideWithValue((qid, body) async {
          seenBody = body;
          return _ans(12);
        }),
      ],
    );
    addTearDown(c.dispose);

    final n = c.read(qnaDetailControllerProvider.notifier);
    await n.load(1);
    await n.submitAnswer('도움이 되는 답변');

    expect(seenBody, '도움이 되는 답변');
    final s = c.read(qnaDetailControllerProvider) as QnaLoaded;
    expect(s.detail.answers, hasLength(2));
  });

  test('load 실패 → QnaFailed', () async {
    final c = ProviderContainer(
      overrides: [
        qnaDetailFetchProvider.overrideWithValue(
          (id) async => throw const ApiException(
            code: ApiErrorCode.forbidden,
            message: '서버 오류',
          ),
        ),
      ],
    );
    addTearDown(c.dispose);
    await c.read(qnaDetailControllerProvider.notifier).load(1);
    expect(c.read(qnaDetailControllerProvider), isA<QnaFailed>());
  });

  test(
    'late A detail cannot paint after mounted controller moves to B',
    () async {
      final aResponse = Completer<CommunityQuestionDetail>();
      var calls = 0;
      final c = ProviderContainer(
        overrides: [
          currentOwnerKeyProvider.overrideWith(
            (ref) => ref.watch(_ownerProvider),
          ),
          qnaDetailFetchProvider.overrideWithValue((id) {
            calls += 1;
            return calls == 1
                ? aResponse.future
                : Future.value(_detail(title: 'B detail'));
          }),
        ],
      );
      addTearDown(c.dispose);
      final subscription = c.listen(qnaDetailControllerProvider, (_, _) {});
      addTearDown(subscription.close);

      final aLoad = c.read(qnaDetailControllerProvider.notifier).load(1);
      await pumpEventQueue();
      c.read(_ownerProvider.notifier).setOwner('owner-b');
      await pumpEventQueue();
      final resetBeforeCompletion = c.read(qnaDetailControllerProvider);
      aResponse.complete(_detail(title: 'A detail'));
      await aLoad;

      expect(resetBeforeCompletion, isA<QnaLoading>());
      expect(c.read(qnaDetailControllerProvider), isA<QnaLoading>());
      await c.read(qnaDetailControllerProvider.notifier).load(1);
      expect(
        (c.read(qnaDetailControllerProvider) as QnaLoaded).detail.title,
        'B detail',
      );
    },
  );

  test('late A mutation refresh cannot paint after owner switch', () async {
    final fresh = Completer<CommunityQuestionDetail>();
    final freshStarted = Completer<void>();
    var fetchCalls = 0;
    final c = ProviderContainer(
      overrides: [
        currentOwnerKeyProvider.overrideWith(
          (ref) => ref.watch(_ownerProvider),
        ),
        qnaDetailFetchProvider.overrideWithValue((id) {
          fetchCalls += 1;
          if (fetchCalls == 1) return Future.value(_detail(title: 'A base'));
          freshStarted.complete();
          return fresh.future;
        }),
        answerAcceptProvider.overrideWithValue((id) async {}),
      ],
    );
    addTearDown(c.dispose);
    final subscription = c.listen(qnaDetailControllerProvider, (_, _) {});
    addTearDown(subscription.close);
    final notifier = c.read(qnaDetailControllerProvider.notifier);
    await notifier.load(1);

    final mutation = notifier.accept(11);
    await freshStarted.future;
    c.read(_ownerProvider.notifier).setOwner('owner-b');
    await pumpEventQueue();
    final resetBeforeCompletion = c.read(qnaDetailControllerProvider);
    fresh.complete(_detail(title: 'A stale refresh'));
    await mutation;

    expect(resetBeforeCompletion, isA<QnaLoading>());
    expect(c.read(qnaDetailControllerProvider), isA<QnaLoading>());
  });

  test('late A mutation error cannot restore A action state for B', () async {
    final action = Completer<void>();
    final c = ProviderContainer(
      overrides: [
        currentOwnerKeyProvider.overrideWith(
          (ref) => ref.watch(_ownerProvider),
        ),
        qnaDetailFetchProvider.overrideWithValue(
          (id) async => _detail(title: 'A base'),
        ),
        answerAcceptProvider.overrideWithValue((id) => action.future),
      ],
    );
    addTearDown(c.dispose);
    final subscription = c.listen(qnaDetailControllerProvider, (_, _) {});
    addTearDown(subscription.close);
    final notifier = c.read(qnaDetailControllerProvider.notifier);
    await notifier.load(1);

    final mutation = notifier.accept(11);
    await pumpEventQueue();
    c.read(_ownerProvider.notifier).setOwner('owner-b');
    await pumpEventQueue();
    final resetBeforeCompletion = c.read(qnaDetailControllerProvider);
    action.completeError(
      const ApiException(
        code: ApiErrorCode.forbidden,
        message: 'stale A error',
      ),
    );
    await mutation;

    expect(resetBeforeCompletion, isA<QnaLoading>());
    expect(c.read(qnaDetailControllerProvider), isA<QnaLoading>());
  });
}

class _OwnerController extends Notifier<String?> {
  @override
  String? build() => 'owner-a';

  void setOwner(String? owner) => state = owner;
}
