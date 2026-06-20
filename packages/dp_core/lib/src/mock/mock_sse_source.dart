import 'dart:convert';

import '../error/api_error_code.dart';
import '../error/api_exception.dart';
import '../sse/sse_event.dart';

/// stage 기반 학습경로 SSE 스트리밍 UX를 재현한다.
class MockSseSource {
  const MockSseSource({
    required this.stages,
    this.delay = const Duration(milliseconds: 600),
    this.failAfter,
    this.donePathId = 101,
  });

  final List<String> stages;
  final Duration delay;

  /// null=정상 완료. N이면 N단계 emit 후 ApiException(network)로 중단.
  final int? failAfter;

  /// done stage payload에 포함할 pathId.
  final int donePathId;

  Stream<SseEvent> stream() async* {
    for (var i = 0; i < stages.length; i++) {
      if (failAfter != null && i >= failAfter!) {
        throw const ApiException(
          code: ApiErrorCode.network,
          message: '연결이 끊겼어요.',
        );
      }
      if (delay > Duration.zero) await Future<void>.delayed(delay);
      yield SseEvent(event: 'progress', data: jsonEncode(_payload(stages[i])));
    }
  }

  Map<String, Object?> _payload(String stage) => {
    'stage': stage,
    'progress': switch (stage) {
      'collecting' => 0.15,
      'generating' => 0.45,
      'matching' => 0.75,
      'done' || 'error' => 1.0,
      _ => 0.0,
    },
    'message': switch (stage) {
      'collecting' => '진단 결과를 분석하고 있어요.',
      'generating' => '개인화 학습경로를 생성하고 있어요.',
      'matching' => '학습 콘텐츠를 매칭하고 있어요.',
      'done' => '학습경로가 준비됐어요.',
      'error' => '경로 생성에 실패했어요.',
      _ => stage,
    },
    'pathId': stage == 'done' ? donePathId : null,
  };
}
