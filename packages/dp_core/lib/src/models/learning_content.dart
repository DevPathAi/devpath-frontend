import 'package:freezed_annotation/freezed_annotation.dart';

part 'learning_content.freezed.dart';
part 'learning_content.g.dart';

@freezed
abstract class LearningContent with _$LearningContent {
  const factory LearningContent({
    required int id,
    required String slug,
    required String title,
    required String track,
    required String markdown,
    int? estimatedMinutes,
    double? difficulty,
    String? bloomLevel,
    @Default(<String>[]) List<String> conceptTags,
    required ContentProgress progress,
  }) = _LearningContent;

  factory LearningContent.fromJson(Map<String, dynamic> json) =>
      _$LearningContentFromJson(json);
}

@freezed
abstract class ContentProgress with _$ContentProgress {
  const factory ContentProgress({
    required double scrollPct,
    required int dwellSec,
    @Default(false) bool completed,
    String? completedAt,
  }) = _ContentProgress;

  factory ContentProgress.fromJson(Map<String, dynamic> json) =>
      _$ContentProgressFromJson(json);
}

@freezed
abstract class ContentProgressUpdateResponse
    with _$ContentProgressUpdateResponse {
  const factory ContentProgressUpdateResponse({
    required double scrollPct,
    required int dwellSec,
    @Default(false) bool completed,
    String? completedAt,
  }) = _ContentProgressUpdateResponse;

  factory ContentProgressUpdateResponse.fromJson(Map<String, dynamic> json) =>
      _$ContentProgressUpdateResponseFromJson(json);
}
