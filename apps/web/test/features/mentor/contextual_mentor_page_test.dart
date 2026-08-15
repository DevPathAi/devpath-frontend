import 'dart:async';

import 'package:devpath_web/src/features/community/data/lcs_source.dart';
import 'package:devpath_web/src/features/dashboard/application/current_mission_controller.dart';
import 'package:devpath_web/src/features/mentor/application/mentor_controller.dart';
import 'package:devpath_web/src/features/mentor/data/mentor_sse_source.dart';
import 'package:devpath_web/src/features/mentor/presentation/mentor_page.dart';
import 'package:devpath_web/src/features/mentor/state/mentor_scope_key.dart';
import 'package:devpath_web/src/features/mentor/state/mentor_state.dart';
import 'package:devpath_web/src/features/mission/state/mission_workspace_key.dart';
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _workspace = MissionWorkspaceKey(taskId: 31, contentId: 3);
const _scope = MentorScopeKey(ownerId: '73', workspaceKey: _workspace);

CurrentMission _mission() => CurrentMission.fromJson({
  'outcome': 'AVAILABLE',
  'pathId': 21,
  'weekNum': 2,
  'tasks': [
    {
      'taskId': 31,
      'orderNum': 1,
      'taskType': 'PRACTICE',
      'title': '예외 처리 코드를 실행해 보기',
      'required': true,
      'contentId': 3,
      'contentSlug': 'content-3',
      'completed': false,
      'completedAt': null,
    },
  ],
  'nextTask': {
    'taskId': 31,
    'orderNum': 1,
    'taskType': 'PRACTICE',
    'title': '예외 처리 코드를 실행해 보기',
    'required': true,
    'contentId': 3,
    'contentSlug': 'content-3',
    'completed': false,
    'completedAt': null,
  },
  'pathCompleted': false,
});

final class _ReadyMission extends CurrentMissionController {
  @override
  CurrentMissionState build() => CurrentMissionState(mission: _mission());
}

MentorContextEvidence _evidence({bool complete = true}) =>
    MentorContextEvidence(
      currentCode: 'throw StateError();',
      session: complete
          ? SandboxSession(
              sessionId: 91,
              language: SandboxLanguage.java,
              contentId: 3,
              codeBlockId: null,
              stdout: 'ok\n',
              stderr: 'StateError\n',
              exitCode: 1,
              status: SandboxSessionStatus.failed,
              truncated: false,
              startedAt: DateTime.utc(2026, 8, 16),
              finishedAt: DateTime.utc(2026, 8, 16, 0, 0, 1),
            )
          : null,
      review: complete
          ? const CodeReview(confidence: 90, strengths: ['명확한 실패 재현'])
          : null,
    );

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  bool includeCode = true,
  bool completeEvidence = true,
  bool commitFails = false,
  StreamController<SseEvent>? mentorStream,
}) async {
  final container = ProviderContainer(
    overrides: [
      mentorClockProvider.overrideWithValue(
        () => DateTime.utc(2026, 8, 16, 12),
      ),
      currentMissionOwnerKeyProvider.overrideWithValue('73'),
      currentMissionControllerProvider.overrideWith(_ReadyMission.new),
      mentorScopeValidatorProvider(_scope).overrideWithValue(() => true),
      mentorContextEvidenceProvider(
        _scope,
      ).overrideWithValue(_evidence(complete: completeEvidence)),
      mentorLcsDraftProvider.overrideWithValue(
        ({
          int? contentId,
          required List<String> requestedFields,
          required Map<String, Object?> requestContext,
        }) async => LcsDraft(
          draftId: 'draft-1',
          expiresAt: DateTime.utc(2026, 8, 16, 12, 10),
          content: {
            'current_content': {
              'contentId': 3,
              'title': '예외 처리 단원',
              'track': 'BACKEND_SPRING',
            },
            if (requestedFields.contains('current_code'))
              'current_code': requestContext['current_code'],
            if (requestedFields.contains('review_summary'))
              'review_summary': requestContext['review_summary'],
          },
          fieldsAvailable: requestedFields
              .where(
                (field) =>
                    field == 'current_content' ||
                    field == 'current_code' ||
                    field == 'review_summary',
              )
              .toList(),
          fieldsUnavailable: requestedFields.contains('recent_output')
              ? const [
                  LcsFieldUnavailable(
                    field: 'recent_output',
                    reason: 'source_unavailable',
                  ),
                ]
              : const [],
        ),
      ),
      mentorLcsCommitProvider.overrideWithValue(({required draftId}) async {
        if (commitFails) {
          throw const ApiException(
            code: ApiErrorCode.resourceNotFound,
            message: '미리보기가 만료됐어요.',
          );
        }
        return 71;
      }),
      mentorContextualSseConnectProvider.overrideWithValue(
        (
          question, {
          String? contentId,
          int? contextSnapshotId,
          int fromStep = 0,
        }) =>
            mentorStream?.stream ??
            Stream.fromIterable(const [
              SseEvent(event: 'token', data: '복구 경로를 분리하세요.'),
              SseEvent(event: 'terminal', data: '{"status":"DONE"}'),
            ]),
      ),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: DpTheme.light(),
        home: MentorPage.contextual(
          scopeKey: _scope,
          includeCurrentCode: includeCode,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return container;
}

void main() {
  testWidgets('Mission Header + 선택 capsule → 실제 preview → private send', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1024, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = await _pump(tester);

    expect(find.byType(DpMissionHeader), findsOneWidget);
    expect(find.text('예외 처리 코드를 실행해 보기'), findsWidgets);
    expect(find.byType(DpContextCapsule), findsOneWidget);
    expect(find.textContaining('LCS'), findsNothing);
    expect(find.text('현재 편집기 코드'), findsOneWidget);
    expect(find.text('최근 오류'), findsOneWidget);
    expect(find.text('제외됨'), findsNWidgets(2));

    await tester.enterText(find.byType(TextField), '왜 실패하나요?');
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('mentor-primary-action')),
          )
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.text('맥락 미리보기'));
    await tester.pumpAndSettle();

    expect(
      container.read(contextualMentorControllerProvider(_scope)).contextPhase,
      MentorContextPhase.previewReady,
    );
    expect(find.text('전송 범위 미리보기'), findsOneWidget);
    expect(find.textContaining('예외 처리 단원'), findsOneWidget);
    expect(find.textContaining('throw StateError'), findsOneWidget);
    expect(find.text('비공개로 질문 보내기'), findsOneWidget);

    await tester.tap(find.text('비공개로 질문 보내기'));
    await tester.pumpAndSettle();

    expect(find.text('복구 경로를 분리하세요.'), findsOneWidget);
    expect(find.textContaining('답변에 사용된 맥락'), findsOneWidget);
    expect(find.textContaining('현재 콘텐츠'), findsWidgets);
    expect(
      container
          .read(contextualMentorControllerProvider(_scope))
          .selectedContextFields,
      isNot(contains('current_code')),
    );
  });

  testWidgets('unavailable source는 이유를 정직하게 표시하고 선택하지 않는다', (tester) async {
    tester.view.physicalSize = const Size(1024, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = await _pump(tester, completeEvidence: false);

    expect(find.text('저장된 실행 결과가 없어요.'), findsNWidgets(2));
    expect(find.text('현재 실행과 연결된 리뷰가 없어요.'), findsOneWidget);
    final state = container.read(contextualMentorControllerProvider(_scope));
    expect(state.selectedContextFields, {'current_content', 'current_code'});
  });

  testWidgets('commit 실패는 질문 입력과 실제 preview를 보존한다', (tester) async {
    tester.view.physicalSize = const Size(1024, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _pump(tester, commitFails: true);

    await tester.enterText(find.byType(TextField), '입력을 지우지 마세요');
    await tester.tap(find.text('맥락 미리보기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('비공개로 질문 보내기'));
    await tester.pumpAndSettle();

    expect(find.text('입력을 지우지 마세요'), findsOneWidget);
    expect(find.textContaining('예외 처리 단원'), findsOneWidget);
    expect(find.text('미리보기가 만료됐어요.'), findsOneWidget);
    expect(find.text('맥락 미리보기 다시 만들기'), findsOneWidget);
  });

  testWidgets('기존 대화 뒤 새 질문 preview는 입력을 지우지 않는다', (tester) async {
    tester.view.physicalSize = const Size(1024, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _pump(tester);

    await tester.enterText(find.byType(TextField), '첫 질문');
    await tester.tap(find.text('맥락 미리보기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('비공개로 질문 보내기'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '둘째 질문');
    await tester.tap(find.text('맥락 미리보기'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      '둘째 질문',
    );
    expect(find.text('비공개로 질문 보내기'), findsOneWidget);
  });

  testWidgets('답변 중 작성한 다음 질문은 이전 답변 성공 뒤에도 보존한다', (tester) async {
    tester.view.physicalSize = const Size(1024, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final stream = StreamController<SseEvent>();
    addTearDown(stream.close);
    await _pump(tester, mentorStream: stream);

    await tester.enterText(find.byType(TextField), '첫 질문');
    await tester.tap(find.text('맥락 미리보기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('비공개로 질문 보내기'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '다음 질문');

    stream.add(const SseEvent(event: 'token', data: '첫 답변'));
    stream.add(const SseEvent(event: 'terminal', data: '{"status":"DONE"}'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      '다음 질문',
    );
  });

  testWidgets('320px·200%에서도 overflow 없이 primary가 하나다', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _pump(tester);

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('mentor-primary-action')), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);
    final capsule = tester.widget<DpContextCapsule>(
      find.byType(DpContextCapsule),
    );
    expect(capsule.mode, DpContextCapsuleMode.collapsed);
  });
}
