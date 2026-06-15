import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/api_providers.dart';

/// 질문을 보내 SSE 토큰을 흘리는 함수.
/// ENG-REVIEW D2: 끊김 후 재요청 시 `fromStep`(이미 받은 토큰 수)/lastToken 자리를
/// 시그니처에 선확보 — 현재 목/실서버는 처음부터 재전송(resend)하지만, 백엔드가
/// `Last-Event-ID`/토큰 재개를 합의하면 여기로 흘려보낸다(추측 금지, 자리만 둠).
typedef MentorSseConnect =
    Stream<SseEvent> Function(String question, {int fromStep});

const List<String> _kMockAnswer = [
  '비동기는 ',
  '`Future`와 ',
  '`async`/`await`로 ',
  '다룹니다. ',
  '스트림은 `Stream`을 구독하세요.',
];

final mentorSseConnectProvider = Provider<MentorSseConnect>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.useMock) {
    return (question, {int fromStep = 0}) async* {
      for (final t in _kMockAnswer.sublist(
        fromStep.clamp(0, _kMockAnswer.length),
      )) {
        await Future<void>.delayed(const Duration(milliseconds: 120));
        yield SseEvent(event: 'token', data: t);
      }
    };
  }
  // ENG-REVIEW D1: `client.dio`를 직접 만지지 않는다 — `SseClient(client.dio)` 직접
  // 인스턴스화 금지. P2 `apiClient.sse(path, {body})` 헬퍼만 경유한다.
  final apiClient = ref.watch(apiClientProvider);
  return (question, {int fromStep = 0}) => apiClient.sse(
    '/ai-mentor/sessions',
    body: {'message': question, 'fromStep': fromStep},
  );
});
