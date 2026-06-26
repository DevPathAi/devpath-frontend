import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/community_source.dart';
import '../state/community_state.dart';

/// 커뮤니티 탭 — 질문 목록(`GET /community/posts`).
class CommunityController extends Notifier<CommunityState> {
  @override
  CommunityState build() => const CommunityLoading();

  Future<void> load() async {
    state = const CommunityLoading();
    try {
      final posts = await ref.read(communityListProvider)();
      state = CommunityLoaded(posts);
    } on ApiException catch (e) {
      state = CommunityFailed(e.message);
    }
  }
}

final communityControllerProvider =
    NotifierProvider<CommunityController, CommunityState>(
      CommunityController.new,
    );
