import 'package:dp_core/dp_core.dart';

/// 마이페이지 합성 상태. 프로필(핵심)은 필수, 집계 섹션은 부분 실패 허용.
sealed class MyPageState {
  const MyPageState();
}

class MyPageLoading extends MyPageState {
  const MyPageLoading();
}

/// 프로필 로드 성공. 집계(dashboard·activity)는 각각 null이면 해당 섹션 에러.
class MyPageLoaded extends MyPageState {
  const MyPageLoaded({
    required this.profile,
    this.dashboard,
    this.activity,
    this.saving = false,
  });

  final ProfileView profile;
  final DashboardSummary? dashboard; // null = 집계 섹션 실패
  final MyActivity? activity; // null = 집계 섹션 실패
  final bool saving;

  MyPageLoaded copyWith({
    ProfileView? profile,
    DashboardSummary? dashboard,
    MyActivity? activity,
    bool? saving,
  }) => MyPageLoaded(
    profile: profile ?? this.profile,
    dashboard: dashboard ?? this.dashboard,
    activity: activity ?? this.activity,
    saving: saving ?? this.saving,
  );
}

/// 프로필(핵심) 로드 실패 → 전체 에러+재시도.
class MyPageFailed extends MyPageState {
  const MyPageFailed(this.message);
  final String message;
}
