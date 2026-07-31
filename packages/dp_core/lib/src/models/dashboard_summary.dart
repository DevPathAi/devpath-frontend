import 'package:freezed_annotation/freezed_annotation.dart';

import 'dashboard_timeseries.dart';

part 'dashboard_summary.freezed.dart';
part 'dashboard_summary.g.dart';

/// 대시보드 요약(DASH-001): 스트릭·진행률·다음 과제·배지.
@freezed
abstract class DashboardSummary with _$DashboardSummary {
  const factory DashboardSummary({
    required int streakDays,
    required int progressPercent,
    String? nextTaskTitle,
    @Default(<String>[]) List<String> badges,
    @Default(0) int completedContentCount,
    @Default(<DailyActivity>[]) List<DailyActivity> weeklyActivity,
    @Default(<ProgressPoint>[]) List<ProgressPoint> progressHistory,
  }) = _DashboardSummary;

  factory DashboardSummary.fromJson(Map<String, dynamic> json) =>
      _$DashboardSummaryFromJson(json);
}
