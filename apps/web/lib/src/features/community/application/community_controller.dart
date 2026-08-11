import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/community_source.dart';
import '../state/community_state.dart';

class CommunityController extends Notifier<CommunityState> {
  @override
  CommunityState build() => const CommunityState();

  /// 보드 필터 전환 → 현재 board로 재조회.
  Future<void> selectBoard(CommunityBoard board) async {
    state = state.copyWith(board: board);
    await load();
  }

  Future<void> load({String? tag, String? sort}) async {
    state = state.copyWith(phase: CommunityPhase.loading);
    try {
      final posts = await ref.read(communityListProvider)(
        board: state.board.value,
        tag: tag,
        sort: sort,
      );
      state = state.copyWith(posts: posts, phase: CommunityPhase.loaded);
    } on ApiException catch (e) {
      state = state.copyWith(phase: CommunityPhase.failed, error: e.message);
    }
  }
}

final communityControllerProvider =
    NotifierProvider<CommunityController, CommunityState>(
      CommunityController.new,
    );
