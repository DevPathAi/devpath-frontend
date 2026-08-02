import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/community_source.dart';
import '../state/community_search_state.dart';

class CommunitySearchController extends Notifier<CommunitySearchState> {
  @override
  CommunitySearchState build() => const CommunitySearchState();

  /// 검색어가 비면 **서버를 부르지 않고** idle 로 되돌린다(화면은 기존 목록으로 복귀).
  Future<void> search(String q, {String? board}) async {
    final query = q.trim();
    if (query.isEmpty) {
      state = const CommunitySearchState();
      return;
    }
    state = state.copyWith(
      query: query,
      phase: CommunitySearchPhase.loading,
      items: const [],
      page: 0,
      total: 0,
    );
    try {
      final r = await ref.read(communitySearchProvider)(q: query, board: board);
      state = state.copyWith(
        items: r.items,
        total: r.total,
        page: r.page,
        phase: CommunitySearchPhase.loaded,
      );
    } on ApiException catch (e) {
      state = state.copyWith(
        phase: CommunitySearchPhase.failed,
        error: e.message,
      );
    }
  }

  /// 다음 페이지를 받아 **기존 결과 뒤에 이어붙인다.** 진행 중이거나 남은 게 없으면 무시한다.
  Future<void> loadMore({String? board}) async {
    if (state.phase != CommunitySearchPhase.loaded ||
        !state.hasMore ||
        state.loadingMore) {
      return;
    }
    state = state.copyWith(loadingMore: true);
    final next = state.page + 1;
    try {
      final r = await ref.read(communitySearchProvider)(
        q: state.query,
        board: board,
        page: next,
      );
      state = state.copyWith(
        items: [...state.items, ...r.items],
        total: r.total,
        page: next,
        loadingMore: false,
      );
    } on ApiException catch (e) {
      // 더보기 실패는 기존 결과를 버리지 않는다 — 첫 로딩 실패와 성격이 다르다.
      state = state.copyWith(loadingMore: false, error: e.message);
    }
  }

  Future<void> retry({String? board}) => search(state.query, board: board);
}

final communitySearchControllerProvider =
    NotifierProvider<CommunitySearchController, CommunitySearchState>(
      CommunitySearchController.new,
    );
