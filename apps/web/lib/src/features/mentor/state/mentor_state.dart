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

/// 참고자료 링크(슬라이스 #7 M-2 `event:references`). ai-svc가 질문 임베딩 →
/// learning 유사검색으로 내려주는 top-K 콘텐츠. mentor feature 내 plain 모델
/// (state 타입과 co-locate; dp_core 모델은 freezed 기반이라 패턴 분리).
class MentorReference {
  const MentorReference({
    required this.contentId,
    required this.slug,
    required this.title,
  });

  final int contentId;
  final String slug;
  final String title;

  factory MentorReference.fromJson(Map<String, dynamic> json) =>
      MentorReference(
        contentId: (json['contentId'] as num).toInt(),
        slug: json['slug'] as String,
        title: json['title'] as String,
      );
}

class MentorState {
  const MentorState({
    this.messages = const [],
    this.status = MentorStatus.idle,
    this.error,
    this.references = const [],
  });
  final List<ChatMessage> messages;
  final MentorStatus status;
  final String? error;

  /// `event:references`(1회) 결과. 도착 전/없으면 빈 리스트.
  final List<MentorReference> references;
}
