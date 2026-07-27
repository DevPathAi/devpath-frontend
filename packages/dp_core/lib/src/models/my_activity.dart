import 'package:freezed_annotation/freezed_annotation.dart';

part 'my_activity.freezed.dart';
part 'my_activity.g.dart';

/// 커뮤니티 활동 집계(GET /community/me/activity).
@freezed
abstract class MyActivity with _$MyActivity {
  const factory MyActivity({
    @Default(0) int questionCount,
    @Default(0) int answerCount,
  }) = _MyActivity;

  factory MyActivity.fromJson(Map<String, dynamic> json) =>
      _$MyActivityFromJson(json);
}
