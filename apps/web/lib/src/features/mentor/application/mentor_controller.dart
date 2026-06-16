import 'dart:async';

import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/mentor_sse_source.dart';
import '../state/mentor_state.dart';

class MentorController extends Notifier<MentorState> {
  StreamSubscription<SseEvent>? _sub;

  @override
  MentorState build() {
    ref.onDispose(() => _sub?.cancel());
    return const MentorState();
  }

  /// 마지막으로 보낸 질문 — partial 끊김 후 "다시 시도"(재전송)용.
  String? _lastQuestion;

  /// 진행 중 send의 future. 새 send가 이전 구독을 취소할 때, 취소된 구독은
  /// onDone/onError가 호출되지 않아 이전 Completer가 영원히 미완료(hang)된다 →
  /// 새 send 시작 시 이전 in-flight를 완료해 대기 중인 future가 풀리게 한다.
  Completer<void>? _inFlight;

  Future<void> send(String question) {
    if (question.trim().isEmpty) return Future.value();
    _sub?.cancel();
    // 취소된 이전 구독의 Completer를 완료(hang 방지).
    if (_inFlight != null && !_inFlight!.isCompleted) _inFlight!.complete();
    _lastQuestion = question;
    final done = Completer<void>();
    _inFlight = done;

    final msgs = [
      ...state.messages,
      ChatMessage(fromUser: true, text: question),
      const ChatMessage(fromUser: false, text: ''),
    ];
    state = MentorState(messages: msgs, status: MentorStatus.streaming);

    // ENG-REVIEW(취소 경쟁조건): 토큰 대상 인덱스를 send 시점에 클로저로 캡처한다.
    // 연속 send 시 이전 스트림의 잔여 콜백이 새 멘토 버블(state.messages.last)에
    // 오append되는 것을 막는다 — append 대상은 항상 이 send가 만든 버블(targetIndex).
    final targetIndex = msgs.length - 1;

    _sub = ref
        .read(mentorSseConnectProvider)(question)
        .listen(
          (e) {
            // 이 send가 만든 버블이 아직 마지막일 때만 갱신(취소된 잔여 콜백 무시).
            if (state.messages.length <= targetIndex) return;
            final m = [...state.messages];
            m[targetIndex] = m[targetIndex].append(e.data);
            state = MentorState(messages: m, status: MentorStatus.streaming);
          },
          onError: (Object err) {
            final isKill = err is ApiException && err.isKillSwitch;
            // ENG-REVIEW D2: 부분답변은 보존하고 재전송 가능한 partial로 둔다.
            // KILL_SWITCH만 점검 분기 — 나머지 끊김은 partial(다시 시도) / API 에러는 failed.
            final MentorStatus status;
            if (isKill) {
              status = MentorStatus.killSwitch;
            } else if (err is ApiException) {
              status = MentorStatus.failed;
            } else {
              status = MentorStatus.partial; // 네트워크 끊김 — 부분답변 보존
            }
            state = MentorState(
              messages: _pruneEmptyMentorBubble(state.messages, targetIndex),
              status: status,
              error: err is ApiException ? err.message : '연결이 끊겼어요',
            );
            if (!done.isCompleted) done.complete();
          },
          onDone: () {
            // ENG-REVIEW(빈/부분 버블 잔류): 토큰 0개로 끝나면 빈 멘토 버블을 제거한다.
            state = MentorState(
              messages: _pruneEmptyMentorBubble(state.messages, targetIndex),
              status: MentorStatus.idle,
            );
            if (!done.isCompleted) done.complete();
          },
          cancelOnError: true,
        );

    return done.future;
  }

  /// 끊김/완료 시 [targetIndex]의 멘토 버블이 비어 있으면 제거(빈 버블 잔류 방지).
  List<ChatMessage> _pruneEmptyMentorBubble(
    List<ChatMessage> msgs,
    int targetIndex,
  ) {
    if (targetIndex < msgs.length &&
        !msgs[targetIndex].fromUser &&
        msgs[targetIndex].text.isEmpty) {
      return [...msgs]..removeAt(targetIndex);
    }
    return msgs;
  }

  /// partial 끊김 후 "다시 시도" — 마지막 질문을 재전송(resend).
  /// ENG-REVIEW D2: 토큰 단위 재개(Last-Event-ID)는 백엔드 합의 후속. 현재는 resend.
  Future<void> retry() {
    final q = _lastQuestion;
    if (q == null) return Future.value();
    return send(q);
  }
}

final mentorControllerProvider =
    NotifierProvider<MentorController, MentorState>(MentorController.new);
