import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/api_providers.dart';

/// SSE 와이어 단계(목 emit 순서). 마지막 DONE은 완료 신호.
/// 카피 정합: 제목/DoD의 "4단계 SSE"는 이 와이어 4단계(ANALYZE·MAP·BUILD·DONE)를 가리키며,
/// DONE은 작업 단계가 아니라 완료 신호다 — 따라서 사용자에게 보이는 진행 라벨은 3개다.
const List<String> kSseSteps = ['ANALYZE', 'MAP', 'BUILD', 'DONE'];

/// 사용자에게 보이는 단계 라벨(DONE 제외 3단계, DESIGN §8 / 스펙 §4).
const List<String> kPathStageLabels = ['GitHub 분석', '약점 매핑', '주차 배치'];

/// `fromStep`(kSseSteps 인덱스)부터 SSE 이벤트를 흘리는 함수.
typedef PathSseConnect = Stream<SseEvent> Function({int fromStep});

/// 목=MockSseSource, 실서버=P2 `apiClient.sse(...)` 헬퍼. useMock로 교체.
/// ENG-REVIEW D1: 앱은 `client.dio`를 직접 만지지 않는다 — `SseClient(client.dio)` 직접
/// 인스턴스화 금지. P2가 제공하는 `apiClient.sse(path, {body})`만 경유한다.
final pathSseConnectProvider = Provider<PathSseConnect>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.useMock) {
    // MockSseSource는 stages 전체 위에서 fromStep을 루프 시작 인덱스로 쓴다
    // (i=fromStep..length). 따라서 sublist가 아니라 전체 kSseSteps를 넘긴다 —
    // sublist+fromStep 동시 적용 시 이중 적용으로 아무 단계도 emit되지 않음.
    return ({int fromStep = 0}) => MockSseSource(
      stages: kSseSteps,
      delay: const Duration(milliseconds: 250),
      fromStep: fromStep,
    ).stream();
  }
  final apiClient = ref.watch(apiClientProvider);
  return ({int fromStep = 0}) => apiClient.sse(
    '/learning-paths/me/generate',
    body: {'fromStep': fromStep},
  );
});
