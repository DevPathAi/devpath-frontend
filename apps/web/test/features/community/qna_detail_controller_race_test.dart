import 'dart:async';

import 'package:devpath_web/src/features/community/application/qna_detail_controller.dart';
import 'package:devpath_web/src/features/community/data/community_source.dart';
import 'package:devpath_web/src/features/community/state/qna_detail_state.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// qnaDetailControllerProvider 는 family 도 autoDispose 도 아닌 **싱글턴**이다. 화면을 옮겨도
// 같은 인스턴스가 살아 있으므로, 질문 1 에서 시작한 뮤테이션이 await 에서 깨어났을 때
// 화면은 이미 질문 2 일 수 있다. 그때 결과를 쓰면 남의 화면을 덮는다.

CommunityQuestionDetail _detail(int id) =>
    CommunityQuestionDetail(id: id, title: 'Q$id', bodyMd: 'B$id');

void main() {
  test('뮤테이션이 실패해도 이미 이동한 질문의 상태를 되돌리지 않는다', () async {
    final gate = Completer<void>();
    final c = ProviderContainer(
      overrides: [
        qnaDetailFetchProvider.overrideWithValue((id) async => _detail(id)),
        answerUpdateProvider.overrideWithValue((id, bodyMd) async {
          await gate.future;
          throw const ApiException(
            code: ApiErrorCode.forbidden,
            message: 'nope',
          );
        }),
      ],
    );
    addTearDown(c.dispose);

    final n = c.read(qnaDetailControllerProvider.notifier);
    await n.load(1);
    final pending = n.updateAnswer(11, '고친 본문'); // 일부러 await 하지 않는다
    await n.load(2); // 그 사이 다른 질문으로 이동
    gate.complete();
    await pending;

    final s = c.read(qnaDetailControllerProvider);
    expect(s, isA<QnaLoaded>());
    expect(
      (s as QnaLoaded).detail.id,
      2,
      reason: '질문 1 의 실패가 질문 2 화면을 덮으면 안 된다',
    );
    expect(s.actionError, isNull, reason: '남의 질문 오류 문구가 뜨면 안 된다');
  });

  test('뮤테이션이 성공해도 이미 이동했으면 재조회하지 않는다', () async {
    final gate = Completer<void>();
    var fetches = 0;
    final c = ProviderContainer(
      overrides: [
        qnaDetailFetchProvider.overrideWithValue((id) async {
          fetches++;
          return _detail(id);
        }),
        answerUpdateProvider.overrideWithValue((id, bodyMd) async {
          await gate.future;
          return CommunityAnswer(id: id, bodyMd: bodyMd);
        }),
      ],
    );
    addTearDown(c.dispose);

    final n = c.read(qnaDetailControllerProvider.notifier);
    await n.load(1);
    final pending = n.updateAnswer(11, '고친 본문');
    await n.load(2);
    expect(fetches, 2, reason: '대조군: 여기까지 load 두 번이 각각 한 번씩 조회했다');

    gate.complete();
    await pending;

    expect(fetches, 2, reason: '이동한 뒤에는 뮤테이션이 재조회를 걸지 않는다');
    expect((c.read(qnaDetailControllerProvider) as QnaLoaded).detail.id, 2);
  });

  test('이동하지 않았으면 평소대로 재조회한다 — 가드가 정상 경로를 막지 않는다', () async {
    var fetches = 0;
    final c = ProviderContainer(
      overrides: [
        qnaDetailFetchProvider.overrideWithValue((id) async {
          fetches++;
          return _detail(id);
        }),
        answerUpdateProvider.overrideWithValue(
          (id, bodyMd) async => CommunityAnswer(id: id, bodyMd: bodyMd),
        ),
      ],
    );
    addTearDown(c.dispose);

    final n = c.read(qnaDetailControllerProvider.notifier);
    await n.load(1);
    await n.updateAnswer(11, '고친 본문');

    expect(fetches, 2, reason: 'load 1 회 + 수정 후 재조회 1 회');
    expect((c.read(qnaDetailControllerProvider) as QnaLoaded).detail.id, 1);
  });
}
