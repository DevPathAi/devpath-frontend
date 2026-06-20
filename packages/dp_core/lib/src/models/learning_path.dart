import 'package:freezed_annotation/freezed_annotation.dart';

part 'learning_path.freezed.dart';
part 'learning_path.g.dart';

/// 학습 경로(PATH-001 결과). 진단 요약 + milestone 기반 12주 타임라인.
@freezed
abstract class LearningPath with _$LearningPath {
  const factory LearningPath({
    required int pathId,
    required String track,
    required int totalWeeks,
    required String rationale,
    PathDiagnosis? diagnosis,
    @Default(<PathMilestone>[]) List<PathMilestone> milestones,
  }) = _LearningPath;

  factory LearningPath.fromJson(Map<String, dynamic> json) =>
      _$LearningPathFromJson(json);
}

@freezed
abstract class PathDiagnosis with _$PathDiagnosis {
  const factory PathDiagnosis({
    required String diagnosedLevel,
    @Default(<String>[]) List<String> strengthConcepts,
    @Default(<String>[]) List<String> weaknessConcepts,
  }) = _PathDiagnosis;

  factory PathDiagnosis.fromJson(Map<String, dynamic> json) =>
      _$PathDiagnosisFromJson(json);
}

@freezed
abstract class PathMilestone with _$PathMilestone {
  const factory PathMilestone({
    required int weekNum,
    required String title,
    required String goalDescription,
    @Default(<String>[]) List<String> targetSkills,
    required int estimatedHours,
    required String whyThisOrder,
    required String expectedOutcome,
    @Default(false) bool locked,
    @Default(<WeeklyTask>[]) List<WeeklyTask> tasks,
  }) = _PathMilestone;

  factory PathMilestone.fromJson(Map<String, dynamic> json) =>
      _$PathMilestoneFromJson(json);
}

@freezed
abstract class WeeklyTask with _$WeeklyTask {
  const factory WeeklyTask({
    required int orderNum,
    required String taskType,
    required String title,
    @Default(false) bool required,
    int? contentId,
    String? contentSlug,
    @Default(false) bool completed,
  }) = _WeeklyTask;

  factory WeeklyTask.fromJson(Map<String, dynamic> json) =>
      _$WeeklyTaskFromJson(json);
}
