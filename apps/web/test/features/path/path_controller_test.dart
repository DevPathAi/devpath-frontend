import 'dart:async';

import 'package:devpath_web/src/app/app_config.dart';
import 'package:devpath_web/src/features/path/application/path_controller.dart';
import 'package:devpath_web/src/features/path/data/path_sse_source.dart';
import 'package:devpath_web/src/providers/api_providers.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// appConfigProvider 오버라이드용 최소 헬퍼(P4a에 전용 헬퍼가 없어 여기서 정의).
AppConfig testAppConfig({Duration? sseTimeout}) => AppConfig(
  baseUrl: 'https://test/api/v1',
  useMock: true,
  sseTimeout: sseTimeout ?? const Duration(seconds: 60),
);

Stream<SseEvent> _emit(List<String> steps) async* {
  for (final s in steps) {
    yield SseEvent(event: 'stage', data: '{"step":"$s"}');
  }
}

Stream<SseEvent> _emitThenError(List<String> steps) async* {
  yield* _emit(steps);
  throw Exception('연결 끊김');
}

void main() {
  test('정상: 4단계 후 완료(타임라인 결과 로드)', () async {
    final container = ProviderContainer(
      overrides: [
        pathSseConnectProvider.overrideWithValue(
          ({int fromStep = 0}) => _emit(kSseSteps.sublist(fromStep)),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(pathControllerProvider.notifier).start();

    final s = container.read(pathControllerProvider);
    expect(s.phase, PathPhase.complete);
    expect(s.completed, kPathStageLabels); // 3단계 모두
    expect(s.result, isNotNull);
    expect(s.result!.weeks, hasLength(12));
    expect(s.result!.weeks.first.tasks, hasLength(3));
  });

  test('DD8: 중단 시 완료 단계 보존 후 이어하기로 완성', () async {
    var calls = 0;
    final container = ProviderContainer(
      overrides: [
        pathSseConnectProvider.overrideWithValue(({int fromStep = 0}) {
          calls++;
          return calls == 1
              ? _emitThenError(['ANALYZE', 'MAP']) // 2단계 후 끊김
              : _emit(kSseSteps.sublist(fromStep)); // 이어하기: BUILD, DONE
        }),
      ],
    );
    addTearDown(container.dispose);

    final ctrl = container.read(pathControllerProvider.notifier);
    await ctrl.start();

    var s = container.read(pathControllerProvider);
    expect(s.phase, PathPhase.partial); // 중단
    expect(s.completed, ['GitHub 분석', '약점 매핑']); // 완료 단계 보존
    expect(s.result, isNull);

    await ctrl.resume(); // 끊긴 지점(fromStep=2)부터

    s = container.read(pathControllerProvider);
    expect(calls, 2); // 전체 재시작 아님 — resume 1회
    expect(s.phase, PathPhase.complete);
    expect(s.completed, kPathStageLabels);
    expect(s.result, isNotNull);
  });

  test(
    'F4: 중간 503(KILL_SWITCH)은 partial이 아니라 killSwitch로 종료(이어하기 루프 차단)',
    () async {
      final container = ProviderContainer(
        overrides: [
          pathSseConnectProvider.overrideWithValue(({int fromStep = 0}) async* {
            yield SseEvent(event: 'stage', data: '{"step":"ANALYZE"}');
            throw const ApiException(
              code: ApiErrorCode.aiKillSwitchActive,
              message: 'AI 처리 일시 중단',
            );
          }),
        ],
      );
      addTearDown(container.dispose);

      await container.read(pathControllerProvider.notifier).start();

      final s = container.read(pathControllerProvider);
      expect(s.phase, PathPhase.killSwitch); // partial 아님 → "이어서 생성" 미노출
      expect(s.completed, ['GitHub 분석']); // 503 직전까지는 보존
    },
  );

  test('D2: 60s 무이벤트 → partial 전환', () async {
    // sseTimeout을 짧게 오버라이드하고, 첫 단계 후 더는 이벤트가 없는(열린) 스트림 주입.
    // async*+무한 await는 구독 취소가 hang하므로, 취소 가능한 StreamController로 무이벤트를 재현.
    final hang = StreamController<SseEvent>();
    hang.add(const SseEvent(event: 'stage', data: '{"step":"ANALYZE"}'));
    addTearDown(hang.close);
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWith(
          (ref) => testAppConfig(sseTimeout: const Duration(milliseconds: 50)),
        ),
        pathSseConnectProvider.overrideWithValue(
          ({int fromStep = 0}) => hang.stream,
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(pathControllerProvider.notifier).start();

    final s = container.read(pathControllerProvider);
    expect(s.phase, PathPhase.partial); // 타임아웃 → 이어하기 가능
    expect(s.completed, ['GitHub 분석']); // 무이벤트 직전 단계 보존
  });
}
