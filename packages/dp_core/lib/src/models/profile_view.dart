import 'package:freezed_annotation/freezed_annotation.dart';

part 'profile_view.freezed.dart';
part 'profile_view.g.dart';

/// 마이페이지 프로필(platform GET/PUT /users/me/profile). 미저장 시 전부 null.
@freezed
abstract class ProfileView with _$ProfileView {
  const factory ProfileView({
    String? avatar,
    String? bio,
    String? learningGoal,
    String? targetTrack,
    int? experienceYears,
  }) = _ProfileView;

  factory ProfileView.fromJson(Map<String, dynamic> json) =>
      _$ProfileViewFromJson(json);
}
