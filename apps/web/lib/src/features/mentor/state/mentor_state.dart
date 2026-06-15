/// 멘토 스트리밍 상태. ENG-REVIEW D1: P2 `SseStage`
/// (connecting/streaming/partial/reconnecting/complete/failed)를 단일 출처로 두고
/// 멘토가 **구독·매핑**한다 — 여기 enum은 그 평행정의를 최소화한 멘토 뷰 모델이며,
/// `partial`은 P4b `PathPhase.partial`과 동일 의미(끊김 시 부분답변 보존 + 재전송 가능).
enum MentorStatus { idle, streaming, partial, killSwitch, failed }

class ChatMessage {
  const ChatMessage({required this.fromUser, required this.text});
  final bool fromUser;
  final String text;
  ChatMessage append(String s) =>
      ChatMessage(fromUser: fromUser, text: text + s);
}

class MentorState {
  const MentorState({
    this.messages = const [],
    this.status = MentorStatus.idle,
    this.error,
  });
  final List<ChatMessage> messages;
  final MentorStatus status;
  final String? error;
}
