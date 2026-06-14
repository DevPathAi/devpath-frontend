import '../error/api_error_code.dart';
import '../error/api_exception.dart';
import '../sse/sse_event.dart';

/// 단계 문자열을 지연 emit해 SSE 스트리밍 UX를 재현(경로생성 4단계 등).
/// D2: [failAfter]로 중단 주입, [fromStep]으로 이어하기(전체 재시작 금지).
class MockSseSource {
  const MockSseSource({
    required this.stages,
    this.delay = const Duration(milliseconds: 600),
    this.failAfter,
    this.fromStep = 0,
  });

  final List<String> stages;
  final Duration delay;

  /// null=정상 완료. N이면 [fromStep] 기준 N단계 emit 후 ApiException(network)로 중단.
  final int? failAfter;

  /// 재개 시작 인덱스(완료 단계 수). 0=처음부터.
  final int fromStep;

  Stream<SseEvent> stream() async* {
    for (var i = fromStep; i < stages.length; i++) {
      if (failAfter != null && i >= fromStep + failAfter!) {
        throw const ApiException(code: ApiErrorCode.network, message: '연결이 끊겼어요.');
      }
      if (delay > Duration.zero) await Future<void>.delayed(delay);
      yield SseEvent(event: 'stage', data: '{"step":"${stages[i]}"}');
    }
  }
}
