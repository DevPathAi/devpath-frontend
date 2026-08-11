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

/// 진행률 추이 1점(백엔드 `ProgressPoint`). [percent]=0~100 전체 누적률.
/// [byType]=과제 유형(READ·PRACTICE·QUIZ)별 누적률. 해당 유형의 과제가 0개면 키가 없다.
/// 백엔드가 먼저 배포되지 않아도 깨지지 않도록 기본값을 빈 맵으로 둔다.
@freezed
abstract class ProgressPoint with _$ProgressPoint {
  const factory ProgressPoint({
    required String date,
    @Default(0) int percent,
    @Default(<String, int>{}) Map<String, int> byType,
  }) = _ProgressPoint;

  factory ProgressPoint.fromJson(Map<String, dynamic> json) =>
      _$ProgressPointFromJson(json);
}
