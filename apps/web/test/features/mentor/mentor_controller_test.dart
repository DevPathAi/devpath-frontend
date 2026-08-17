import 'dart:async';
import 'dart:convert';

import 'package:devpath_web/src/features/community/data/lcs_source.dart';
import 'package:devpath_web/src/features/dashboard/application/current_mission_controller.dart';
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
  yield const SseEvent(event: 'terminal', data: '{"status":"DONE"}');
}

final _ownerProvider = NotifierProvider<_OwnerController, String?>(
  _OwnerController.new,
);

final class _OwnerController extends Notifier<String?> {
  @override
  String? build() => 'owner-a';

  void switchTo(String owner) => state = owner;
}

void main() {
  test('contextless send는 LCS draft/commit을 호출하지 않는다', () async {
    var draftCalls = 0;
    var commitCalls = 0;
    final c = ProviderContainer(
      overrides: [
        mentorLcsDraftProvider.overrideWithValue(({
          int? contentId,
          required List<String> requestedFields,
          required Map<String, Object?> requestContext,
        }) async {
          draftCalls += 1;
          throw StateError('contextless must not draft');
        }),
        mentorLcsCommitProvider.overrideWithValue(({required draftId}) async {
          commitCalls += 1;
          throw StateError('contextless must not commit');
        }),
        mentorSseConnectProvider.overrideWithValue(
          (question, {String? contentId, int fromStep = 0}) => _tokens(['답변']),
        ),
      ],
    );
    addTearDown(c.dispose);

    await c.read(mentorControllerProvider.notifier).send('전역 질문');

    expect(draftCalls, 0);
    expect(commitCalls, 0);
    expect(c.read(mentorControllerProvider).messages.last.text, '답변');
  });

  test('질문 전송 → 사용자+멘토 메시지, 토큰 누적 후 idle', () async {
    final c = ProviderContainer(
      overrides: [
        mentorSseConnectProvider.overrideWithValue(
          (q, {String? contentId, int fromStep = 0}) => _tokens(['안녕', '하세요']),
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
          (q, {String? contentId, int fromStep = 0}) => Stream<SseEvent>.error(
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
    Stream<SseEvent> partial(
      String q, {
      String? contentId,
      int fromStep = 0,
    }) async* {
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

  test(
    'old FE→new AI: null snapshot legacy token+EOF는 idle success를 유지한다',
    () async {
      final c = ProviderContainer(
        overrides: [
          mentorSseConnectProvider.overrideWithValue(
            (q, {String? contentId, int fromStep = 0}) =>
                Stream.value(const SseEvent(event: 'token', data: '기존 답변')),
          ),
        ],
      );
      addTearDown(c.dispose);

      await c.read(mentorControllerProvider.notifier).send('질문');
      final s = c.read(mentorControllerProvider);
      expect(s.status, MentorStatus.idle);
      expect(s.messages.last.text, '기존 답변');
    },
  );

  test('global /mentor는 A pending→B에서 즉시 reset하고 A late event를 무시한다', () async {
    final stream = StreamController<SseEvent>();
    final c = ProviderContainer(
      overrides: [
        currentMissionOwnerKeyProvider.overrideWith(
          (ref) => ref.watch(_ownerProvider),
        ),
        mentorSseConnectProvider.overrideWithValue(
          (question, {String? contentId, int fromStep = 0}) => stream.stream,
        ),
      ],
    );
    addTearDown(() async {
      await stream.close();
      c.dispose();
    });

    final pending = c.read(mentorControllerProvider.notifier).send('A 질문');
    stream.add(const SseEvent(event: 'token', data: 'A 답변'));
    stream.add(
      SseEvent(
        event: 'references',
        data: jsonEncode(const [
          {'contentId': 7, 'slug': 'a', 'title': 'A 참고'},
        ]),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(c.read(mentorControllerProvider).messages, isNotEmpty);
    expect(c.read(mentorControllerProvider).references, isNotEmpty);

    c.read(_ownerProvider.notifier).switchTo('owner-b');
    await Future<void>.delayed(Duration.zero);

    var state = c.read(mentorControllerProvider);
    expect(state.status, MentorStatus.idle);
    expect(state.messages, isEmpty);
    expect(state.references, isEmpty);
    stream.add(const SseEvent(event: 'token', data: 'A 늦은 토큰'));
    await Future<void>.delayed(Duration.zero);
    state = c.read(mentorControllerProvider);
    expect(state.messages, isEmpty);
    expect(state.references, isEmpty);
    await pending;
  });

  // ENG-REVIEW(취소 경쟁조건): 연속 send 시 잔여 콜백이 새 버블에 오append되지 않는다.
  test('연속 send: 이전 스트림의 잔여 토큰이 새 버블을 오염시키지 않는다', () async {
    final first = StreamController<SseEvent>();
    var call = 0;
    final c = ProviderContainer(
      overrides: [
        mentorSseConnectProvider.overrideWithValue((
          q, {
          String? contentId,
          int fromStep = 0,
        }) {
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

  test('references 이벤트 → state.references 반영(버블 미오염)', () async {
    Stream<SseEvent> withRefs(
      String q, {
      String? contentId,
      int fromStep = 0,
    }) async* {
      yield SseEvent(event: 'token', data: '답변');
      yield SseEvent(
        event: 'references',
        data: jsonEncode(const [
          {'contentId': 7, 'slug': 'async', 'title': '비동기'},
        ]),
      );
      yield const SseEvent(event: 'terminal', data: '{"status":"DONE"}');
    }

    final c = ProviderContainer(
      overrides: [mentorSseConnectProvider.overrideWithValue(withRefs)],
    );
    addTearDown(c.dispose);

    await c.read(mentorControllerProvider.notifier).send('질문');
    final s = c.read(mentorControllerProvider);

    expect(s.status, MentorStatus.idle);
    // 토큰만 버블에 — references는 버블에 append되지 않는다.
    expect(s.messages.last.text, '답변');
    expect(s.references, hasLength(1));
    expect(s.references.single.contentId, 7);
    expect(s.references.single.slug, 'async');
    expect(s.references.single.title, '비동기');
  });

  test('references 없이 토큰만 와도 정상(references 빈 리스트 유지)', () async {
    final c = ProviderContainer(
      overrides: [
        mentorSseConnectProvider.overrideWithValue(
          (q, {String? contentId, int fromStep = 0}) => _tokens(['토큰']),
        ),
      ],
    );
    addTearDown(c.dispose);

    await c.read(mentorControllerProvider.notifier).send('질문');
    final s = c.read(mentorControllerProvider);
    expect(s.status, MentorStatus.idle);
    expect(s.messages.last.text, '토큰');
    expect(s.references, isEmpty);
  });

  test('토큰 뒤 terminal timeout은 부분답변과 safe retry 상태를 보존한다', () async {
    Stream<SseEvent> timeout(
      String question, {
      String? contentId,
      int fromStep = 0,
    }) async* {
      yield const SseEvent(event: 'token', data: '받은 부분');
      yield const SseEvent(
        event: 'terminal',
        data:
            '{"status":"FAILED","code":"AI_TIMEOUT",'
            '"message":"mentor response timed out"}',
      );
    }

    final c = ProviderContainer(
      overrides: [mentorSseConnectProvider.overrideWithValue(timeout)],
    );
    addTearDown(c.dispose);

    await c.read(mentorControllerProvider.notifier).send('질문');
    final state = c.read(mentorControllerProvider);
    expect(state.status, MentorStatus.partial);
    expect(state.messages.last.text, '받은 부분');
    expect(state.error, contains('시간'));
  });

  test('토큰 전 FAILED terminal은 성공으로 닫지 않고 failed를 보존한다', () async {
    Stream<SseEvent> failed(
      String question, {
      String? contentId,
      int fromStep = 0,
    }) async* {
      yield const SseEvent(
        event: 'terminal',
        data:
            '{"status":"FAILED","code":"PROVIDER_FAILURE",'
            '"message":"답변을 생성하지 못했어요."}',
      );
    }

    final c = ProviderContainer(
      overrides: [mentorSseConnectProvider.overrideWithValue(failed)],
    );
    addTearDown(c.dispose);

    await c.read(mentorControllerProvider.notifier).send('질문');
    final state = c.read(mentorControllerProvider);
    expect(state.status, MentorStatus.failed);
    expect(state.messages, hasLength(1));
    expect(state.error, '답변을 생성하지 못했어요.');
  });

  test('pre-SSE MENTOR_BUSY는 quota와 별도 retryable 상태다', () async {
    final c = ProviderContainer(
      overrides: [
        mentorSseConnectProvider.overrideWithValue(
          (question, {String? contentId, int fromStep = 0}) =>
              Stream<SseEvent>.error(
                const ApiException(
                  code: ApiErrorCode.mentorBusy,
                  status: 429,
                  message: 'mentor is busy; retry later',
                ),
              ),
        ),
      ],
    );
    addTearDown(c.dispose);

    await c.read(mentorControllerProvider.notifier).send('질문');
    final state = c.read(mentorControllerProvider);
    expect(state.status, MentorStatus.busy);
    expect(state.messages, hasLength(1));
    expect(state.error, contains('잠시 후'));
  });

  test('QUOTA_EXCEEDED 429의 기존 failed 상태와 서버 카피는 유지한다', () async {
    final c = ProviderContainer(
      overrides: [
        mentorSseConnectProvider.overrideWithValue(
          (question, {String? contentId, int fromStep = 0}) =>
              Stream<SseEvent>.error(
                const ApiException(
                  code: ApiErrorCode.quotaExceeded,
                  status: 429,
                  message: '질문 한도를 모두 사용했어요.',
                ),
              ),
        ),
      ],
    );
    addTearDown(c.dispose);

    await c.read(mentorControllerProvider.notifier).send('질문');
    final state = c.read(mentorControllerProvider);
    expect(state.status, MentorStatus.failed);
    expect(state.error, '질문 한도를 모두 사용했어요.');
  });

  test('terminal 뒤 late token과 EOF는 완료 답변을 다시 바꾸지 않는다', () async {
    final stream = StreamController<SseEvent>();
    final c = ProviderContainer(
      overrides: [
        mentorSseConnectProvider.overrideWithValue(
          (question, {String? contentId, int fromStep = 0}) => stream.stream,
        ),
      ],
    );
    addTearDown(() async {
      await stream.close();
      c.dispose();
    });
    final pending = c.read(mentorControllerProvider.notifier).send('질문');
    stream.add(const SseEvent(event: 'token', data: '완료 답변'));
    stream.add(const SseEvent(event: 'terminal', data: '{"status":"DONE"}'));
    await pending;
    stream.add(const SseEvent(event: 'token', data: '늦은 오염'));
    await Future<void>.delayed(Duration.zero);

    final state = c.read(mentorControllerProvider);
    expect(state.status, MentorStatus.idle);
    expect(state.messages.last.text, '완료 답변');
  });
}
