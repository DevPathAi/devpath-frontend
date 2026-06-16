import 'package:freezed_annotation/freezed_annotation.dart';

part 'learning_path.freezed.dart';
part 'learning_path.g.dart';

/// 학습 경로(PATH-001 결과). 12주 타임라인 + 멘토 rationale.
@freezed
abstract class LearningPath with _$LearningPath {
  const factory LearningPath({
    required String rationale,
    @Default(<PathWeek>[]) List<PathWeek> weeks,
  }) = _LearningPath;

  factory LearningPath.fromJson(Map<String, dynamic> json) =>
      _$LearningPathFromJson(json);
}

@freezed
abstract class PathWeek with _$PathWeek {
  const factory PathWeek({
    required int week,
    required String title,
    @Default(<WeeklyTask>[]) List<WeeklyTask> tasks,
  }) = _PathWeek;

  factory PathWeek.fromJson(Map<String, dynamic> json) =>
      _$PathWeekFromJson(json);
}

@freezed
abstract class WeeklyTask with _$WeeklyTask {
  const factory WeeklyTask({required String title, @Default(false) bool done}) =
      _WeeklyTask;

  factory WeeklyTask.fromJson(Map<String, dynamic> json) =>
      _$WeeklyTaskFromJson(json);
}
