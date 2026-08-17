import '../models/current_mission.dart';
import '../models/learning_path.dart';
import 'api_client.dart';

/// 현재 학습 경로와 서버 판정 미션을 공유하는 API 경계.
class LearningPathApi {
  LearningPathApi(this.client);

  static const _currentPathEndpoint = '/learning-paths/me';
  static const _currentMissionEndpoint = '/learning-paths/me/this-week';

  final ApiClient client;

  Future<LearningPath> currentPath() async {
    final data = await client.get<Map<String, dynamic>>(_currentPathEndpoint);
    return LearningPath.fromJson(data);
  }

  Future<CurrentMission> currentMission() async {
    final data = await client.get<Object?>(_currentMissionEndpoint);
    return CurrentMission.fromJson(data);
  }

  /// 콘텐츠가 연결되지 않은 과제만 명시적으로 완료한다.
  Future<void> completeContentlessTask(int taskId) async {
    if (taskId <= 0) {
      throw ArgumentError.value(taskId, 'taskId', '양수여야 합니다');
    }
    await client.post<void>('/learning-paths/tasks/$taskId/complete');
  }
}
