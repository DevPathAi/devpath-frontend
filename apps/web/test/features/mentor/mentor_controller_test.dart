import 'dart:async';

import 'package:devpath_web/src/features/mentor/application/mentor_controller.dart';
import 'package:devpath_web/src/features/mentor/data/mentor_sse_source.dart';
import 'package:devpath_web/src/features/mentor/state/mentor_state.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Stream<SseEvent> _tokens(List<String> t) async* {
  for (final x in t) {
    yield SseEvent(event: 'token', data: x);
  }
}

void main() {
  test('질문 전송 → 사용자+멘토 메시지, 토큰 누적 후 idle', () async {
    final c = ProviderContainer(
      overrides: [
        mentorSseConnectProvider.overrideWithValue(
          (q, {int fromStep = 0}) => _tokens(['안녕', '하세요']),
        ),
      ],
    );
    addTearDown(c.dispose);

    await c.read(mentorControllerProvider.notifier).send('질문');

    final s = c.read(mentorControllerProvider);
    expect(s.status, MentorStatus.idle);
    expect(s.messages, hasLength(2));
    expect(s.messages[0].fromUser, isTrue);
    expect(s.messages[0].text, '질문');
    expect(s.messages[1].fromUser, isFalse);
    expect(s.messages[1].text, '안녕하세요');
  });

  test('KILL_SWITCH면 status killSwitch', () async {
    final c = ProviderContainer(
      overrides: [
        mentorSseConnectProvider.overrideWithValue(
          (q, {int fromStep = 0}) => Stream<SseEvent>.error(
            const ApiException(
              code: ApiErrorCode.aiKillSwitchActive,
              message: '점검',
            ),
          ),
        ),
      ],
    );
    addTearDown(c.dispose);

    await c.read(mentorControllerProvider.notifier).send('질문');
    expect(c.read(mentorControllerProvider).status, MentorStatus.killSwitch);
  });

  // ENG-REVIEW D2: 끊김 시 부분답변 보존(partial) — failed로 버리지 않는다.
  test('부분 토큰 후 끊기면 status partial + 받은 토큰 보존', () async {
    Stream<SseEvent> partial(String q, {int fromStep = 0}) async* {
      yield SseEvent(event: 'token', data: '부분');
      throw Exception('연결 끊김');
    }

    final c = ProviderContainer(
      overrides: [mentorSseConnectProvider.overrideWithValue(partial)],
    );
    addTearDown(c.dispose);

    await c.read(mentorControllerProvider.notifier).send('질문');
    final s = c.read(mentorControllerProvider);
    expect(s.status, MentorStatus.partial);
    expect(s.messages.last.text, '부분'); // 보존
  });

  // ENG-REVIEW(F9 인접): 토큰 0개로 끝나면 빈 멘토 버블이 남지 않는다.
  test('토큰 0개 onDone 시 빈 멘토 버블은 제거된다', () async {
    final c = ProviderContainer(
      overrides: [
        mentorSseConnectProvider.overrideWithValue(
          (q, {int fromStep = 0}) => const Stream<SseEvent>.empty(),
        ),
      ],
    );
    addTearDown(c.dispose);

    await c.read(mentorControllerProvider.notifier).send('질문');
    final s = c.read(mentorControllerProvider);
    expect(s.status, MentorStatus.idle);
    // 사용자 버블만 — 빈 멘토 버블 잔류 없음.
    expect(s.messages, hasLength(1));
    expect(s.messages.single.fromUser, isTrue);
  });

  // ENG-REVIEW(취소 경쟁조건): 연속 send 시 잔여 콜백이 새 버블에 오append되지 않는다.
  test('연속 send: 이전 스트림의 잔여 토큰이 새 버블을 오염시키지 않는다', () async {
    final first = StreamController<SseEvent>();
    var call = 0;
    final c = ProviderContainer(
      overrides: [
        mentorSseConnectProvider.overrideWithValue((q, {int fromStep = 0}) {
          call++;
          return call == 1 ? first.stream : _tokens(['두번째']);
        }),
      ],
    );
    addTearDown(c.dispose);
    final ctrl = c.read(mentorControllerProvider.notifier);

    final f1 = ctrl.send('첫'); // 미완 스트림(보류)
    await ctrl.send('둘'); // 새 send → 첫 구독 취소
    first.add(SseEvent(event: 'token', data: '늦은토큰')); // 잔여 콜백
    await first.close();
    await f1;

    final s = c.read(mentorControllerProvider);
    // 둘째 답변 버블이 '늦은토큰'으로 오염되지 않음.
    expect(s.messages.last.text, '두번째');
    expect(s.messages.map((m) => m.text), isNot(contains('늦은토큰')));
  });
}
