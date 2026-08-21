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

  test('ABA(1→2→1) 이동 뒤 옛 실패가 새 상태를 덮지 않는다', () async {
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
    final pending = n.updateAnswer(11, '고친 본문');
    await n.load(2);
    await n.load(1); // 같은 id 로 돌아왔다 — 화면은 방금 새로 읽은 Q1 이다
    gate.complete();
    await pending;

    final s = c.read(qnaDetailControllerProvider);
    expect(s, isA<QnaLoaded>());
    expect(
      (s as QnaLoaded).actionError,
      isNull,
      reason:
          'id 비교만으로는 ABA 를 못 가른다 — 옛 실패의 스냅샷 복원이 '
          '새로 읽은 Q1 을 덮고 남의 오류 문구를 띄운다',
    );
    expect(s.submitting, isFalse);
  });

  test('refreshIfShowing: 보고 있는 질문이 아니면 재조회하지 않는다', () async {
    var fetches = 0;
    final c = ProviderContainer(
      overrides: [
        qnaDetailFetchProvider.overrideWithValue((id) async {
          fetches++;
          return _detail(id);
        }),
      ],
    );
    addTearDown(c.dispose);

    final n = c.read(qnaDetailControllerProvider.notifier);
    await n.load(1);
    await n.load(2);
    expect(fetches, 2);

    // 삭제 완료 콜백이 늦게 도착한 상황 — Q1 을 지웠지만 화면은 이미 Q2 다.
    await n.refreshIfShowing(1);
    expect(fetches, 2, reason: '남의 화면을 옛 질문으로 덮으면 안 된다');
    expect((c.read(qnaDetailControllerProvider) as QnaLoaded).detail.id, 2);

    await n.refreshIfShowing(2);
    expect(fetches, 3, reason: '보고 있는 질문이면 평소대로 재조회한다');
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
