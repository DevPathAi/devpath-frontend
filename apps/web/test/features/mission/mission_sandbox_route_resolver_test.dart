import 'package:devpath_web/src/app/app_config.dart';
import 'package:devpath_web/src/features/dashboard/application/current_mission_controller.dart';
import 'package:devpath_web/src/features/mission/presentation/mission_sandbox_route_resolver.dart';
import 'package:devpath_web/src/features/mission/state/mission_workspace_key.dart';
import 'package:devpath_web/src/features/sandbox/presentation/sandbox_page.dart';
import 'package:devpath_web/src/providers/api_providers.dart';
import 'package:dio/dio.dart';
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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

CurrentMission _available() {
  final task = <String, Object?>{
    'taskId': 302,
    'orderNum': 1,
    'taskType': 'PRACTICE',
    'title': '에러 처리 실습',
    'required': true,
    'contentId': 77,
    'contentSlug': 'async-error-handling',
    'completed': false,
    'completedAt': null,
  };
  return CurrentMission.fromJson({
    'outcome': 'AVAILABLE',
    'pathId': 301,
    'weekNum': 4,
    'tasks': [task],
    'nextTask': task,
    'pathCompleted': false,
  });
}

Future<void> _pump(
  WidgetTester tester, {
  required String? taskId,
  required bool enabled,
  required _MissionApi api,
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
        currentMissionOwnerKeyProvider.overrideWithValue('route-user'),
      ],
      child: MaterialApp(
        theme: DpTheme.light(),
        home: MissionSandboxRouteResolver(taskId: taskId),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('유효한 task만 authoritative content pair와 함께 Sandbox에 전달한다', (
    tester,
  ) async {
    final api = _MissionApi(_available());
    await _pump(tester, taskId: '302', enabled: true, api: api);

    final page = tester.widget<SandboxPage>(find.byType(SandboxPage));
    expect(api.calls, 1);
    expect(
      page.workspaceKey,
      const MissionWorkspaceKey(taskId: 302, contentId: 77),
    );
  });

  testWidgets('잘못됐거나 현재 계정에 없는 task는 Sandbox를 열지 않는다', (tester) async {
    for (final taskId in <String?>['0', '999']) {
      final api = _MissionApi(_available());
      await _pump(tester, taskId: taskId, enabled: true, api: api);

      expect(find.byType(SandboxPage), findsNothing);
      expect(find.text('오늘로 돌아가기'), findsOneWidget);
      expect(api.calls, taskId == '0' ? 0 : 1);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('flag OFF는 Today 요청이나 canonical Sandbox를 만들지 않는다', (
    tester,
  ) async {
    final api = _MissionApi(_available());
    await _pump(tester, taskId: '302', enabled: false, api: api);

    expect(api.calls, 0);
    expect(find.byType(SandboxPage), findsNothing);
    expect(find.text('오늘로 돌아가기'), findsOneWidget);
  });
}
