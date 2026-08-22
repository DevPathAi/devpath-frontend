import 'dart:async';

import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';

import '../data/web_mock_fixtures.dart';
import '../features/content/presentation/content_page.dart';
import '../features/dashboard/application/current_mission_controller.dart';
import '../features/dashboard/presentation/widgets/today_mission_section.dart';
import '../features/mentor/presentation/web_mentor_context_projection.dart';
import '../features/path/presentation/mission_path_plan_view.dart';
import '../features/review/presentation/review_panel.dart';
import '../features/sandbox/presentation/monaco_editor_view.dart';
import '../features/sandbox/presentation/sandbox_layout.dart';

export '../features/content/presentation/content_page.dart'
    show WebContentProjection;
export '../features/dashboard/presentation/widgets/today_mission_section.dart'
    show TodayMissionSection;
export '../features/mentor/presentation/web_mentor_context_projection.dart'
    show WebMentorContextProjection;
export '../features/path/presentation/mission_path_plan_view.dart'
    show MissionPathPlanView;
export '../features/review/presentation/review_panel.dart'
    show WebReviewProjection;
export '../features/sandbox/presentation/monaco_editor_view.dart'
    show MonacoEditorView;

class Et13WebEvidenceApp extends StatefulWidget {
  const Et13WebEvidenceApp({
    super.key,
    required this.fixtureId,
    required this.brightness,
    required this.textScale,
    required this.sourceSha,
    this.waitForFonts = waitForEt13EvidenceFonts,
  });

  static const fixtureIds = <String>[
    'web-today-available',
    'web-path-current-week',
    'web-content-reading',
    'web-workspace-idle',
    'web-review-loaded',
    'web-mentor-context-preview',
    'dp-design-mission-ledger',
    'dp-design-context-payload-preview',
  ];

  final String fixtureId;
  final Brightness brightness;
  final double textScale;
  final String sourceSha;
  final Et13ReadyWaiter waitForFonts;

  @override
  State<Et13WebEvidenceApp> createState() => _Et13WebEvidenceAppState();
}

class _Et13WebEvidenceAppState extends State<Et13WebEvidenceApp> {
  late final _surfaceReady = Completer<void>();

  @override
  Widget build(BuildContext context) {
    final waitsForWorkspace = widget.fixtureId == 'web-workspace-idle';
    return DpEt13EvidenceFrame(
      fixtureId: widget.fixtureId,
      brightness: widget.brightness,
      textScale: widget.textScale,
      sourceSha: widget.sourceSha,
      waitForFonts: widget.waitForFonts,
      waitForSurface: waitsForWorkspace ? () => _surfaceReady.future : null,
      child: buildEt13WebFixture(
        widget.fixtureId,
        onWorkspaceReady: () {
          if (!_surfaceReady.isCompleted) _surfaceReady.complete();
        },
      ),
    );
  }
}

Widget buildEt13WebFixture(String fixtureId, {VoidCallback? onWorkspaceReady}) {
  final mission = CurrentMission.fromJson(mockCurrentMission());
  return switch (fixtureId) {
    'web-today-available' => Scaffold(
      body: SingleChildScrollView(
        child: TodayMissionSection(
          state: CurrentMissionState(mission: mission),
          onRetry: () {},
          onOpenPath: () {},
          onOpenContent: (_) {},
          onCompleteContentless: (_) {},
        ),
      ),
    ),
    'web-path-current-week' => Scaffold(
      body: SingleChildScrollView(
        child: MissionPathPlanView(
          missionState: CurrentMissionState(mission: mission),
          plan: LearningPath.fromJson(mockLearningPath()),
          onRetryMission: () {},
          onRetryPlan: () {},
          onOpenContent: (_) {},
          onCompleteContentless: (_) {},
        ),
      ),
    ),
    'web-content-reading' => Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(DpSpacing.lg),
        child: WebContentProjection(
          content: LearningContent.fromJson(mockContent('future-async-await')),
          adSlot: const _Et13OfflineAdSlot(),
        ),
      ),
    ),
    'web-workspace-idle' => _Et13WorkspaceFixture(onReady: onWorkspaceReady),
    'web-review-loaded' => const Scaffold(
      body: WebReviewProjection(
        review: CodeReview(
          id: 'et13-review-501',
          status: 'DONE',
          confidence: 87,
          strengths: ['비동기 흐름을 작은 함수로 분리했어요.', '테스트 가능한 반환값을 유지했어요.'],
          improvements: [
            ReviewIssue(
              message: '실패 경로에서 오류 타입을 보존하세요.',
              line: 7,
              severity: 'warning',
            ),
          ],
          security: [
            ReviewIssue(
              message: '외부 입력을 로그에 그대로 남기지 마세요.',
              line: 11,
              severity: 'error',
            ),
          ],
        ),
      ),
    ),
    'web-mentor-context-preview' => Scaffold(
      body: WebMentorContextProjection(
        mission: mission,
        task: mission.nextTask,
        capsuleMode: DpContextCapsuleMode.payloadPreview,
        capsuleStatus: DpContextCapsuleStatus.ready,
        onDisclosurePressed: () {},
        onFieldEditRequested: (_) {},
        fields: const [
          DpContextFieldViewModel(
            id: 'current_content',
            label: '현재 콘텐츠',
            valueSummary: '에러 처리 패턴 적용 · BACKEND',
            source: '현재 미션',
            sensitivity: DpContextSensitivity.low,
            inclusion: DpContextInclusion.included,
            editable: true,
          ),
          DpContextFieldViewModel(
            id: 'current_code',
            label: '현재 편집기 코드',
            valueSummary: 'Future<int> answer() async => 42;',
            source: '현재 워크스페이스',
            sensitivity: DpContextSensitivity.potentiallySensitive,
            inclusion: DpContextInclusion.included,
            editable: true,
          ),
          DpContextFieldViewModel(
            id: 'recent_errors',
            label: '최근 오류',
            valueSummary: '최근 실행 오류가 없어요.',
            source: '최근 실행',
            sensitivity: DpContextSensitivity.potentiallySensitive,
            inclusion: DpContextInclusion.rejected,
          ),
          DpContextFieldViewModel(
            id: 'review_summary',
            label: '기존 코드 리뷰',
            valueSummary: '신뢰도 87% · 오류 타입 보존',
            source: '현재 리뷰',
            sensitivity: DpContextSensitivity.medium,
            inclusion: DpContextInclusion.included,
            editable: true,
          ),
        ],
      ),
    ),
    'dp-design-mission-ledger' => const Scaffold(
      body: SingleChildScrollView(
        padding: EdgeInsets.all(DpSpacing.lg),
        child: DpEt13MissionLedgerFixture(),
      ),
    ),
    'dp-design-context-payload-preview' => const Scaffold(
      body: SingleChildScrollView(
        padding: EdgeInsets.all(DpSpacing.lg),
        child: DpEt13ContextPayloadPreviewFixture(),
      ),
    ),
    _ => throw ArgumentError.value(
      fixtureId,
      'fixtureId',
      'unknown web ET13 fixture',
    ),
  };
}

class _Et13WorkspaceFixture extends StatelessWidget {
  const _Et13WorkspaceFixture({this.onReady});

  final VoidCallback? onReady;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const DpPageHeader(
          title: '코드 실습',
          description: '현재 미션의 코드를 실행하고 리뷰를 준비합니다',
        ),
        Expanded(
          child: SandboxLayout(
            editor: MonacoEditorView(
              initialCode:
                  'Future<int> answer() async {\n  return 42;\n}\n\nvoid main() async {\n  print(await answer());\n}',
              language: SandboxLanguage.node,
              onReady: onReady,
            ),
            log: const DpEmpty(
              title: '아직 실행하지 않았어요',
              message: '코드를 실행하면 표준 출력과 오류가 여기에 표시됩니다.',
            ),
            review: const DpEmpty(
              title: '아직 리뷰가 없어요',
              message: '실행을 완료한 뒤 AI 리뷰를 요청할 수 있습니다.',
            ),
          ),
        ),
      ],
    ),
  );
}

class _Et13OfflineAdSlot extends StatelessWidget {
  const _Et13OfflineAdSlot();

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'ET13_BLOCKED_NETWORK:CONTENT_PAGE',
    child: const DpEmpty(
      title: '광고 영역',
      message: '네트워크 없는 증거 캡처에서는 외부 광고 요청을 차단합니다.',
    ),
  );
}
