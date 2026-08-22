import 'package:devpath_mobile/src/features/mission/presentation/mobile_mission_route_resolvers.dart';
import 'package:devpath_mobile/src/features/today/application/today_controller.dart';
import 'package:devpath_mobile/src/features/today/data/current_mission_cache.dart';
import 'package:devpath_mobile/src/providers/api_providers.dart';
import 'package:dio/dio.dart';
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/mock_api.dart';

CurrentMission _mission() {
  final task = <String, Object?>{
    'taskId': 1001,
    'orderNum': 1,
    'taskType': 'READ',
    'title': '현재 미션',
    'required': true,
    'contentId': 1,
    'contentSlug': 'canonical-content',
    'completed': false,
    'completedAt': null,
  };
  return CurrentMission.fromJson(<String, Object?>{
    'outcome': 'AVAILABLE',
    'pathId': 101,
    'weekNum': 1,
    'tasks': <Object?>[task],
    'nextTask': task,
    'pathCompleted': false,
  });
}

final class _MissionApi extends LearningPathApi {
  _MissionApi(this.mission) : super(ApiClient(Dio()));

  final CurrentMission mission;

  @override
  Future<CurrentMission> currentMission() async => mission;
}

Widget _host({required String taskId, required String contentId}) {
  final contentClient = mockApiClient(<String, MockFixture>{
    'GET /contents/1': (
      200,
      <String, Object?>{
        'id': 1,
        'slug': 'canonical-content',
        'title': '검증된 콘텐츠',
        'track': 'BACKEND',
        'markdown': '# 본문',
        'conceptTags': <Object?>[],
        'progress': <String, Object?>{
          'scrollPct': 0.0,
          'dwellSec': 0,
          'completed': false,
          'completedAt': null,
        },
      },
    ),
  });
  return ProviderScope(
    overrides: [
      todayOwnerKeyProvider.overrideWithValue('owner-a'),
      currentMissionCacheProvider.overrideWithValue(
        InMemoryCurrentMissionCache(),
      ),
      learningPathApiProvider.overrideWithValue(_MissionApi(_mission())),
      apiClientProvider.overrideWithValue(contentClient),
    ],
    child: MaterialApp(
      theme: DpTheme.light(),
      home: MobileMissionContentRouteResolver(
        taskId: taskId,
        contentId: contentId,
      ),
    ),
  );
}

void main() {
  testWidgets('authoritative task/content pair가 아니면 콘텐츠를 열지 않는다', (
    tester,
  ) async {
    await tester.pumpWidget(_host(taskId: '1001', contentId: '2'));
    await tester.pumpAndSettle();

    expect(find.textContaining('현재 서버 경로와 일치하지 않아'), findsOneWidget);
    expect(find.text('검증된 콘텐츠'), findsNothing);
  });

  testWidgets('authoritative pair 확인 뒤에만 canonical content를 연다', (
    tester,
  ) async {
    await tester.pumpWidget(_host(taskId: '1001', contentId: '1'));
    await tester.pumpAndSettle();

    expect(find.text('검증된 콘텐츠'), findsOneWidget);
    expect(find.text('# 본문'), findsNothing);
  });
}
