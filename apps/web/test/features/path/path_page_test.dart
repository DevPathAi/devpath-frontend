import 'dart:convert';

import 'package:devpath_web/src/features/auth/application/auth_controller.dart';
import 'package:devpath_web/src/features/auth/state/auth_state.dart';
import 'package:devpath_web/src/features/path/application/path_controller.dart';
import 'package:devpath_web/src/features/path/data/path_sse_source.dart';
import 'package:devpath_web/src/features/path/presentation/path_page.dart';
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
  throw Exception('끊김');
}

Widget _host(ProviderContainer c) => UncontrolledProviderScope(
  container: c,
  child: MaterialApp(theme: DpTheme.light(), home: const PathPage()),
);

class _AuthedAuthController extends AuthController {
  @override
  AuthState build() => const AuthAuthenticated(
    User(
      id: '73',
      email: 'e2e@devpath.local',
      nickname: 'E2E',
      role: UserRole.learner,
      onboardingStatus: OnboardingStatus.done,
    ),
  );
}

void main() {
  testWidgets('완료 시 12주 타임라인과 이번 주 과제를 렌더', (tester) async {
    final c = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(_AuthedAuthController.new),
        pathSseConnectProvider.overrideWithValue(() => _emit(kPathStages)),
      ],
    );
    addTearDown(c.dispose);

    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();

    expect(c.read(pathControllerProvider).phase, PathPhase.complete);
    expect(find.textContaining('비동기 기초'), findsWidgets); // week1 제목
    expect(find.text('Stream 구독 실습'), findsOneWidget); // 이번 주 과제
  });

  testWidgets('중단 시 "다시 생성" 노출', (tester) async {
    final c = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(_AuthedAuthController.new),
        pathSseConnectProvider.overrideWithValue(
          () => _emitThenError(['collecting', 'generating']),
        ),
      ],
    );
    addTearDown(c.dispose);

    await c.read(pathControllerProvider.notifier).start();
    await tester.pumpWidget(_host(c));
    await tester.pump(const Duration(milliseconds: 100));

    expect(c.read(pathControllerProvider).phase, PathPhase.partial);
    expect(find.text('다시 생성'), findsOneWidget);
    expect(find.byType(DpSseStageView), findsOneWidget); // 완료 단계 보존 표시

    // §9.2 PARTIAL: 완료 단계만이 아니라 kPathStageLabels 전체(미완 스켈레톤 포함)를 표시.
    final stageView = tester.widget<DpSseStageView>(
      find.byType(DpSseStageView),
    );
    expect(stageView.stages, kPathStageLabels); // 3단계 전부(미완 단계도 노출)
    expect(stageView.currentIndex, 2); // collecting·generating 완료
  });
}
