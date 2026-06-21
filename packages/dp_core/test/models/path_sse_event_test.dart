import 'package:dp_core/src/models/path_sse_event.dart';
import 'package:test/test.dart';

void main() {
  test('collecting 이벤트는 pathId 없이 역직렬화된다', () {
    final event = PathSseEvent.fromJson({
      'stage': 'collecting',
      'progress': 0.15,
      'message': '진단 결과를 분석하고 있어요.',
    });

    expect(event.stage, 'collecting');
    expect(event.progress, 0.15);
    expect(event.pathId, isNull);
  });

  test('done 이벤트는 pathId를 포함한다', () {
    final event = PathSseEvent.fromJson({
      'stage': 'done',
      'progress': 1.0,
      'message': '학습경로가 준비됐어요.',
      'pathId': 101,
    });

    expect(event.stage, 'done');
    expect(event.pathId, 101);
  });

  test('error 이벤트는 서버 메시지를 보존한다', () {
    final event = PathSseEvent.fromJson({
      'stage': 'error',
      'progress': 1.0,
      'message': 'NO_COMPLETED_ASSESSMENT',
    });

    expect(event.stage, 'error');
    expect(event.message, 'NO_COMPLETED_ASSESSMENT');
  });
}
