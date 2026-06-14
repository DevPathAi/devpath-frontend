/// 파싱된 SSE 이벤트(`event:` 옵션 + `data:` 페이로드).
class SseEvent {
  const SseEvent({this.event, required this.data});
  final String? event;
  final String data;
}

/// 전송계층 단계(DD8 — 이어하기 UX는 feature가 이 신호로 구성).
enum SseStage { connecting, streaming, partial, reconnecting, complete, failed }
