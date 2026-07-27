import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/mypage_source.dart';
import '../state/mypage_state.dart';

/// 마이페이지: 프로필(핵심) + 집계(dashboard·activity) 병렬 로드·합성.
/// 프로필 실패=전체 에러, 집계 부분 실패=해당 섹션만 null.
class MyPageController extends Notifier<MyPageState> {
  @override
  MyPageState build() => const MyPageLoading();

  Future<void> load() async {
    state = const MyPageLoading();
    final ProfileView profile;
    try {
      profile = await ref.read(myProfileFetchProvider)();
    } on ApiException catch (e) {
      state = MyPageFailed(e.message);
      return;
    }
    // 집계는 부분 실패 허용 — 각각 독립 처리.
    final results = await Future.wait([
      _safe(() => ref.read(myDashboardFetchProvider)()),
      _safe(() => ref.read(myActivityFetchProvider)()),
    ]);
    state = MyPageLoaded(
      profile: profile,
      dashboard: results[0] as DashboardSummary?,
      activity: results[1] as MyActivity?,
    );
  }

  Future<void> saveProfile(Map<String, dynamic> body) async {
    final cur = state;
    if (cur is! MyPageLoaded) return;
    state = cur.copyWith(saving: true);
    try {
      final updated = await ref.read(myProfileUpdateProvider)(body);
      state = cur.copyWith(profile: updated, saving: false);
    } on ApiException {
      state = cur.copyWith(saving: false);
      rethrow; // 화면이 스낵바로 처리
    }
  }

  Future<void> uploadAvatar({
    required List<int> bytes,
    required String filename,
    String? contentType,
  }) async {
    final cur = state;
    if (cur is! MyPageLoaded) return;
    state = cur.copyWith(saving: true);
    try {
      final updated = await ref.read(myAvatarUploadProvider)(
        bytes: bytes,
        filename: filename,
        contentType: contentType,
      );
      state = cur.copyWith(profile: updated, saving: false);
    } on ApiException {
      state = cur.copyWith(saving: false);
      rethrow;
    }
  }

  Future<T?> _safe<T>(Future<T> Function() f) async {
    try {
      return await f();
    } on ApiException {
      return null;
    }
  }
}

final myPageControllerProvider =
    NotifierProvider<MyPageController, MyPageState>(MyPageController.new);
