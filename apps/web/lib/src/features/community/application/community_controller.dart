import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/community_source.dart';
import '../state/community_state.dart';

class CommunityController extends Notifier<CommunityState> {
  @override
  CommunityState build() => const CommunityState();

  Future<void> load() async {
    state = const CommunityState(phase: CommunityPhase.loading);
    try {
      final page = await ref.read(communityFetchProvider)();
      state = CommunityState(
        posts: page.data,
        nextCursor: page.nextCursor,
        phase: CommunityPhase.loaded,
      );
    } on ApiException catch (e) {
      state = CommunityState(phase: CommunityPhase.failed, error: e.message);
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.loadingMore) return;
    state = state.copyWith(loadingMore: true, nextCursor: state.nextCursor);
    try {
      final page = await ref.read(communityFetchProvider)(
        cursor: state.nextCursor,
      );
      state = state.copyWith(
        posts: [...state.posts, ...page.data],
        nextCursor: page.nextCursor,
        loadingMore: false,
      );
    } on ApiException catch (e) {
      state = state.copyWith(
        loadingMore: false,
        nextCursor: state.nextCursor,
        error: e.message,
      );
    }
  }
}

final communityControllerProvider =
    NotifierProvider<CommunityController, CommunityState>(
      CommunityController.new,
    );
