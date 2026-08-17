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

  factory ContentProgress.fromJson(Map<String, dynamic> json) {
    final progress = _$ContentProgressFromJson(json);
    _validateProgress(
      scrollPct: progress.scrollPct,
      dwellSec: progress.dwellSec,
      completed: progress.completed,
      completedAt: progress.completedAt,
    );
    return progress;
  }
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

  factory ContentProgressUpdateResponse.fromJson(Map<String, dynamic> json) {
    final response = _$ContentProgressUpdateResponseFromJson(json);
    _validateProgress(
      scrollPct: response.scrollPct,
      dwellSec: response.dwellSec,
      completed: response.completed,
      completedAt: response.completedAt,
    );
    return response;
  }
}

void _validateProgress({
  required double scrollPct,
  required int dwellSec,
  required bool completed,
  required String? completedAt,
}) {
  if (!scrollPct.isFinite || scrollPct < 0 || scrollPct > 1 || dwellSec < 0) {
    throw const FormatException('invalid content progress range');
  }
  if (!completed) {
    if (completedAt != null) {
      throw const FormatException('incomplete progress has completedAt');
    }
    return;
  }
  if (completedAt == null ||
      !RegExp(r'(?:[zZ]|[+-]\d{2}:\d{2})$').hasMatch(completedAt) ||
      DateTime.tryParse(completedAt) == null) {
    throw const FormatException('completed progress lacks a valid instant');
  }
}
