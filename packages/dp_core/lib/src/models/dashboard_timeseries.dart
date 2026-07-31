import 'package:freezed_annotation/freezed_annotation.dart';

part 'dashboard_timeseries.freezed.dart';
part 'dashboard_timeseries.g.dart';

/// 주간 학습량 1일치(백엔드 `DailyActivity`). [date]=ISO 날짜(yyyy-MM-dd) 문자열.
@freezed
abstract class DailyActivity with _$DailyActivity {
  const factory DailyActivity({
    required String date,
    @Default(0) int completedCount,
  }) = _DailyActivity;

  factory DailyActivity.fromJson(Map<String, dynamic> json) =>
      _$DailyActivityFromJson(json);
}

/// 진행률 추이 1점(백엔드 `ProgressPoint`). [percent]=0~100.
@freezed
abstract class ProgressPoint with _$ProgressPoint {
  const factory ProgressPoint({required String date, @Default(0) int percent}) =
      _ProgressPoint;

  factory ProgressPoint.fromJson(Map<String, dynamic> json) =>
      _$ProgressPointFromJson(json);
}
