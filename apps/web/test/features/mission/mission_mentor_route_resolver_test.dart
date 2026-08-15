import 'package:devpath_web/src/app/app_config.dart';
import 'package:devpath_web/src/features/community/data/lcs_source.dart';
import 'package:devpath_web/src/features/dashboard/application/current_mission_controller.dart';
import 'package:devpath_web/src/features/mentor/presentation/mentor_page.dart';
import 'package:devpath_web/src/features/mentor/state/mentor_scope_key.dart';
import 'package:devpath_web/src/features/mission/presentation/mission_mentor_route_resolver.dart';
import 'package:devpath_web/src/features/mission/state/mission_workspace_key.dart';
import 'package:devpath_web/src/providers/api_providers.dart';
import 'package:dio/dio.dart';
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _workspace = MissionWorkspaceKey(taskId: 302, contentId: 77);
const _scope = MentorScopeKey(ownerId: 'route-user', workspaceKey: _workspace);

final class _MissionApi extends LearningPathApi {
  _MissionApi(this.mission) : super(ApiClient(Dio()));
  final CurrentMission mission;
  var calls = 0;

  @override
  Future<CurrentMission> currentMission() async {
    calls += 1;
    return mission;
  }
}

CurrentMission _available() => CurrentMission.fromJson({
  'outcome': 'AVAILABLE',
  'pathId': 301,
  'weekNum': 4,
  'tasks': [
    {
      'taskId': 302,
      'orderNum': 1,
      'taskType': 'PRACTICE',
      'title': '에러 처리 실습',
      'required': true,
      'contentId': 77,
      'contentSlug': 'async-error-handling',
      'completed': false,
      'completedAt': null,
    },
  ],
  'nextTask': {
    'taskId': 302,
    'orderNum': 1,
    'taskType': 'PRACTICE',
    'title': '에러 처리 실습',
    'required': true,
    'contentId': 77,
    'contentSlug': 'async-error-handling',
    'completed': false,
    'completedAt': null,
  },
  'pathCompleted': false,
});

Future<void> _pump(
  WidgetTester tester, {
  required String? taskId,
  required bool enabled,
  required _MissionApi api,
  MentorEntryIntent? intent,
  String owner = 'route-user',
  void Function(MentorScopeKey scope, bool includeCode)? onBuild,
  void Function()? onDraft,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(
          AppConfig(
            baseUrl: 'https://mock.devpath.ai',
            useMock: true,
            missionSpineEnabled: enabled,
          ),
        ),
        learningPathApiProvider.overrideWithValue(api),
        currentMissionOwnerKeyProvider.overrideWithValue(owner),
        mentorLcsDraftProvider.overrideWithValue(({
          int? contentId,
          required List<String> requestedFields,
          required Map<String, Object?> requestContext,
        }) async {
          onDraft?.call();
          throw StateError('route must not draft');
        }),
      ],
      child: MaterialApp(
        theme: DpTheme.light(),
        home: MissionMentorRouteResolver(
          taskId: taskId,
          entryIntent: intent,
          mentorBuilder: (context, scope, includeCode) {
            onBuild?.call(scope, includeCode);
            return MentorPage.contextual(
              scopeKey: scope,
              includeCurrentCode: includeCode,
            );
          },
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1));
  await tester.pump();
}

void main() {
  testWidgets('유효한 task를 owner+task/content Mentor scope로 해석한다', (
    tester,
  ) async {
    final api = _MissionApi(_available());
    MentorScopeKey? captured;
    bool? includeCode;
    var drafts = 0;
    await _pump(
      tester,
      taskId: '302',
      enabled: true,
      api: api,
      intent: const MentorEntryIntent(
        scopeKey: _scope,
        includeCurrentCode: true,
      ),
      onBuild: (scope, include) {
        captured = scope;
        includeCode = include;
      },
      onDraft: () => drafts += 1,
    );

    expect(api.calls, 1);
    expect(captured, _scope);
    expect(includeCode, isTrue);
    expect(drafts, 0, reason: 'route resolution must not draft context');
  });

  testWidgets('다른 owner의 stale intent는 code opt-in을 승계하지 않는다', (tester) async {
    final api = _MissionApi(_available());
    bool? includeCode;
    await _pump(
      tester,
      taskId: '302',
      enabled: true,
      api: api,
      intent: const MentorEntryIntent(
        scopeKey: MentorScopeKey(
          ownerId: 'old-owner',
          workspaceKey: _workspace,
        ),
        includeCurrentCode: true,
      ),
      onBuild: (_, include) => includeCode = include,
    );

    expect(includeCode, isFalse);
  });

  testWidgets('invalid/mismatched task는 Mentor와 LCS를 열지 않는다', (tester) async {
    for (final taskId in <String?>['0', '999']) {
      final api = _MissionApi(_available());
      var built = 0;
      var drafts = 0;
      await _pump(
        tester,
        taskId: taskId,
        enabled: true,
        api: api,
        onBuild: (_, _) => built += 1,
        onDraft: () => drafts += 1,
      );
      expect(built, 0);
      expect(drafts, 0);
      expect(find.text('오늘로 돌아가기'), findsOneWidget);
      expect(api.calls, taskId == '0' ? 0 : 1);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('flag OFF는 Today/Mentor/LCS 신규 경로를 모두 건너뛴다', (tester) async {
    final api = _MissionApi(_available());
    var built = 0;
    var drafts = 0;
    await _pump(
      tester,
      taskId: '302',
      enabled: false,
      api: api,
      onBuild: (_, _) => built += 1,
      onDraft: () => drafts += 1,
    );

    expect(api.calls, 0);
    expect(built, 0);
    expect(drafts, 0);
    expect(find.text('오늘로 돌아가기'), findsOneWidget);
  });
}
