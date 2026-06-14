import 'package:devpath_web/src/features/path/application/path_controller.dart';
import 'package:devpath_web/src/features/path/data/path_sse_source.dart';
import 'package:devpath_web/src/features/path/presentation/path_page.dart';
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Stream<SseEvent> _emit(List<String> steps) async* {
  for (final s in steps) {
    yield SseEvent(event: 'stage', data: '{"step":"$s"}');
  }
}

Stream<SseEvent> _emitThenError(List<String> steps) async* {
  yield* _emit(steps);
  throw Exception('끊김');
}

Widget _host(ProviderContainer c) => UncontrolledProviderScope(
  container: c,
  child: MaterialApp(theme: DpTheme.light(), home: const PathPage()),
);

void main() {
  testWidgets('완료 시 12주 타임라인과 이번 주 과제를 렌더', (tester) async {
    final c = ProviderContainer(
      overrides: [
        pathSseConnectProvider.overrideWithValue(
          ({int fromStep = 0}) => _emit(kSseSteps.sublist(fromStep)),
        ),
      ],
    );
    addTearDown(c.dispose);

    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();

    expect(c.read(pathControllerProvider).phase, PathPhase.complete);
    expect(find.textContaining('비동기 기초'), findsWidgets); // week1 제목
    expect(find.text('Stream 구독 실습'), findsOneWidget); // 이번 주 과제
  });

  testWidgets('중단 시 "이어서 생성" 노출(DD8)', (tester) async {
    final c = ProviderContainer(
      overrides: [
        pathSseConnectProvider.overrideWithValue(
          ({int fromStep = 0}) => _emitThenError(['ANALYZE', 'MAP']),
        ),
      ],
    );
    addTearDown(c.dispose);

    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();

    expect(c.read(pathControllerProvider).phase, PathPhase.partial);
    expect(find.text('이어서 생성'), findsOneWidget);
    expect(find.byType(DpSseStageView), findsOneWidget); // 완료 단계 보존 표시

    // §9.2 PARTIAL: 완료 단계만이 아니라 kPathStageLabels 전체(미완 스켈레톤 포함)를 표시.
    final stageView = tester.widget<DpSseStageView>(
      find.byType(DpSseStageView),
    );
    expect(stageView.stages, kPathStageLabels); // 3단계 전부(미완 단계도 노출)
    expect(stageView.currentIndex, 2); // ANALYZE·MAP 완료 → 남은 1단계가 스켈레톤
  });
}
