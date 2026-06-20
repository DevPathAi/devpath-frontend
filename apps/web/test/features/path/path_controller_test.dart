import 'dart:async';
import 'dart:convert';

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

Stream<SseEvent> _emit(List<String> stages) async* {
  for (final s in stages) {
    yield SseEvent(
      event: 'progress',
      data: jsonEncode({
        'stage': s,
        'progress': s == 'done' ? 1.0 : 0.5,
        'message': s,
        'pathId': s == 'done' ? 101 : null,
      }),
    );
  }
}

Stream<SseEvent> _emitThenError(List<String> stages) async* {
  yield* _emit(stages);
  throw Exception('연결 끊김');
}

void main() {
  test('정상: 4단계 후 완료(타임라인 결과 로드)', () async {
    final container = ProviderContainer(
      overrides: [
        pathSseConnectProvider.overrideWithValue(() => _emit(kPathStages)),
      ],
    );
    addTearDown(container.dispose);

    await container.read(pathControllerProvider.notifier).start();

    final s = container.read(pathControllerProvider);
    expect(s.phase, PathPhase.complete);
    expect(s.completed, kPathStageLabels); // 3단계 모두
    expect(s.result, isNotNull);
    expect(s.result!.milestones, hasLength(12));
    expect(s.result!.milestones.first.tasks, hasLength(3));
  });

  test('기존 경로가 있으면 생성 SSE를 시작하지 않고 바로 로드한다', () async {
    final container = ProviderContainer(
      overrides: [
        pathSseConnectProvider.overrideWithValue(
          () => throw StateError('existing path should not regenerate'),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(pathControllerProvider.notifier).loadOrStart();

    final s = container.read(pathControllerProvider);
    expect(s.phase, PathPhase.complete);
    expect(s.completed, kPathStageLabels);
    expect(s.result, isNotNull);
  });

  test('중단 시 완료 단계 보존 후 다시 생성으로 처음부터 완성', () async {
    var calls = 0;
    final container = ProviderContainer(
      overrides: [
        pathSseConnectProvider.overrideWithValue(() {
          calls++;
          return calls == 1
              ? _emitThenError(['collecting', 'generating'])
              : _emit(kPathStages);
        }),
      ],
    );
    addTearDown(container.dispose);

    final ctrl = container.read(pathControllerProvider.notifier);
    await ctrl.start();

    var s = container.read(pathControllerProvider);
    expect(s.phase, PathPhase.partial); // 중단
    expect(s.completed, ['진단 분석', '경로 생성']); // 완료 단계 보존
    expect(s.result, isNull);

    await ctrl.start(); // 처음부터 다시 생성

    s = container.read(pathControllerProvider);
    expect(calls, 2);
    expect(s.phase, PathPhase.complete);
    expect(s.completed, kPathStageLabels);
    expect(s.result, isNotNull);
  });

  test(
    'F4: 중간 503(KILL_SWITCH)은 partial이 아니라 killSwitch로 종료(이어하기 루프 차단)',
    () async {
      final container = ProviderContainer(
        overrides: [
          pathSseConnectProvider.overrideWithValue(() async* {
            yield SseEvent(
              event: 'progress',
              data: jsonEncode({
                'stage': 'collecting',
                'progress': 0.15,
                'message': 'collecting',
              }),
            );
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
      expect(s.phase, PathPhase.killSwitch); // partial 아님
      expect(s.completed, ['진단 분석']); // 503 직전까지는 보존
    },
  );

  test('D2: 60s 무이벤트 → partial 전환', () async {
    // sseTimeout을 짧게 오버라이드하고, 첫 단계 후 더는 이벤트가 없는(열린) 스트림 주입.
    // async*+무한 await는 구독 취소가 hang하므로, 취소 가능한 StreamController로 무이벤트를 재현.
    final hang = StreamController<SseEvent>();
    hang.add(
      SseEvent(
        event: 'progress',
        data: jsonEncode({
          'stage': 'collecting',
          'progress': 0.15,
          'message': 'collecting',
        }),
      ),
    );
    addTearDown(hang.close);
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWith(
          (ref) => testAppConfig(sseTimeout: const Duration(milliseconds: 50)),
        ),
        pathSseConnectProvider.overrideWithValue(() => hang.stream),
      ],
    );
    addTearDown(container.dispose);

    await container.read(pathControllerProvider.notifier).start();

    final s = container.read(pathControllerProvider);
    expect(s.phase, PathPhase.partial); // 타임아웃 → 다시 생성 가능
    expect(s.completed, ['진단 분석']); // 무이벤트 직전 단계 보존
  });

  test('서버 error stage는 failed로 종료한다', () async {
    final container = ProviderContainer(
      overrides: [
        pathSseConnectProvider.overrideWithValue(() => _emit(['error'])),
      ],
    );
    addTearDown(container.dispose);

    await container.read(pathControllerProvider.notifier).start();

    final s = container.read(pathControllerProvider);
    expect(s.phase, PathPhase.failed);
    expect(s.error, 'error');
  });
}
