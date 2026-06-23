import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/api_providers.dart';

/// 실행 로그 SSE 스트림 생성기.
/// D-3 반영: language 파라미터 추가(JAVA/NODE/PYTHON). 목 분기는 무시.
/// 테스트 override는 `(code, language) => stream` 형태.
typedef SandboxRunConnect =
    Stream<SseEvent> Function(String code, String language);

const List<String> _kMockRunLog = [
  '> dart run main.dart',
  '컴파일 중…',
  '테스트 1/2 통과',
  '테스트 2/2 통과',
  '완료 (0.8s)',
];

final sandboxRunConnectProvider = Provider<SandboxRunConnect>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.useMock) {
    return (String code, String language) async* {
      for (final line in _kMockRunLog) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        yield SseEvent(event: 'log', data: line);
      }
      yield const SseEvent(event: 'session', data: '1');
    };
  }
  // 실API: body에 code + language 포함(설계서 §5 D-3).
  final client = ref.watch(apiClientProvider);
  return (String code, String language) =>
      client.sse('/sandbox/run', body: {'code': code, 'language': language});
});
