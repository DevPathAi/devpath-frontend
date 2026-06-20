import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/api_providers.dart';

/// SSE 와이어 단계(learning-svc `PathProgressEvent.stage`).
const List<String> kPathStages = [
  'collecting',
  'generating',
  'matching',
  'done',
];

/// 사용자에게 보이는 단계 라벨(done 제외 3단계).
const List<String> kPathStageLabels = ['진단 분석', '경로 생성', '콘텐츠 매칭'];

typedef PathSseConnect = Stream<SseEvent> Function();

/// 목=MockSseSource, 실서버=P2 `apiClient.sse(...)` 헬퍼. useMock로 교체.
/// ENG-REVIEW D1: 앱은 `client.dio`를 직접 만지지 않는다 — `SseClient(client.dio)` 직접
/// 인스턴스화 금지. P2가 제공하는 `apiClient.sse(path, {body})`만 경유한다.
final pathSseConnectProvider = Provider<PathSseConnect>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.useMock) {
    return () => MockSseSource(
      stages: kPathStages,
      delay: const Duration(milliseconds: 250),
    ).stream();
  }
  final apiClient = ref.watch(apiClientProvider);
  return () => apiClient.sse('/learning-paths/me/generate');
});
