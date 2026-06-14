import '../sse/sse_event.dart';

/// 단계 문자열을 지연 emit해 SSE 스트리밍 UX를 재현(경로생성 4단계 등).
class MockSseSource {
  const MockSseSource({
    required this.stages,
    this.delay = const Duration(milliseconds: 600),
  });

  final List<String> stages;
  final Duration delay;

  Stream<SseEvent> stream() async* {
    for (final step in stages) {
      if (delay > Duration.zero) await Future<void>.delayed(delay);
      yield SseEvent(event: 'stage', data: '{"step":"$step"}');
    }
  }
}
