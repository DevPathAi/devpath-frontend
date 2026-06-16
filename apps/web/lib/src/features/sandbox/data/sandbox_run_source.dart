import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/api_providers.dart';

/// 실행 로그 SSE 스트림 생성기.
/// F5/D1 반영: 실행할 코드를 전달받아 실서버 분기에서 body로 보낼 수 있게 `code`를 받는다.
/// (목 분기는 code를 무시.) 테스트 override는 `(_) => stream` 형태.
typedef SandboxRunConnect = Stream<SseEvent> Function(String code);

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
    return (String code) async* {
      for (final line in _kMockRunLog) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        yield SseEvent(event: 'log', data: line);
      }
    };
  }
  // F5/D1 반영: `client.dio` 직접 접근 금지 → P2 Task 10 `apiClient.sse(path,{body})`만 사용.
  final client = ref.watch(apiClientProvider);
  return (String code) => client.sse('/sandbox/run', body: {'code': code});
});
