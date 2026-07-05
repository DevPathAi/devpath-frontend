import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/api_providers.dart';

/// 마이페이지 데이터 레이어 — 각 svc REST를 apiClient로 호출.
/// 목 모드는 MockHttpAdapter(픽스처)가 처리하므로 여기서 목 분기를 두지 않는다.
/// 테스트는 각 프로바이더를 inline override해 HTTP 없이 검증한다(community_source 패턴 승계).
typedef MyProfileFetch = Future<ProfileView> Function();
typedef MyProfileUpdate =
    Future<ProfileView> Function(Map<String, dynamic> body);
typedef MyAvatarUpload =
    Future<ProfileView> Function({
      required List<int> bytes,
      required String filename,
      String? contentType,
    });
typedef MyDashboardFetch = Future<DashboardSummary> Function();
typedef MyActivityFetch = Future<MyActivity> Function();

/// `GET /users/me/profile` → ProfileView(미저장 시 전부 null).
final myProfileFetchProvider = Provider<MyProfileFetch>((ref) {
  final client = ref.watch(apiClientProvider);
  return () async {
    final json = await client.get<Map<String, dynamic>>('/users/me/profile');
    return ProfileView.fromJson(json);
  };
});

/// `PUT /users/me/profile {bio,learningGoal,targetTrack,experienceYears}` → ProfileView.
final myProfileUpdateProvider = Provider<MyProfileUpdate>((ref) {
  final client = ref.watch(apiClientProvider);
  return (body) async {
    final json = await client.put<Map<String, dynamic>>(
      '/users/me/profile',
      body: body,
    );
    return ProfileView.fromJson(json);
  };
});

/// `POST /users/me/avatar`(multipart part=file) → ProfileView(avatar 갱신).
final myAvatarUploadProvider = Provider<MyAvatarUpload>((ref) {
  final client = ref.watch(apiClientProvider);
  return ({
    required List<int> bytes,
    required String filename,
    String? contentType,
  }) async {
    final json = await client.postMultipart<Map<String, dynamic>>(
      '/users/me/avatar',
      bytes: bytes,
      filename: filename,
      contentType: contentType,
    );
    return ProfileView.fromJson(json);
  };
});

/// `GET /dashboard/me` → DashboardSummary(+completedContentCount).
final myDashboardFetchProvider = Provider<MyDashboardFetch>((ref) {
  final client = ref.watch(apiClientProvider);
  return () async {
    final json = await client.get<Map<String, dynamic>>('/dashboard/me');
    return DashboardSummary.fromJson(json);
  };
});

/// `GET /community/me/activity` → MyActivity(questionCount·answerCount).
final myActivityFetchProvider = Provider<MyActivityFetch>((ref) {
  final client = ref.watch(apiClientProvider);
  return () async {
    final json = await client.get<Map<String, dynamic>>(
      '/community/me/activity',
    );
    return MyActivity.fromJson(json);
  };
});
