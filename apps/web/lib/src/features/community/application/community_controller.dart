import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/community_source.dart';
import '../state/community_state.dart';

class CommunityController extends Notifier<CommunityState> {
  @override
  CommunityState build() => const CommunityState();

  Future<void> load({String? board, String? tag, String? sort}) async {
    state = const CommunityState(phase: CommunityPhase.loading);
    try {
      final posts = await ref.read(communityListProvider)(
        board: board,
        tag: tag,
        sort: sort,
      );
      state = CommunityState(posts: posts, phase: CommunityPhase.loaded);
    } on ApiException catch (e) {
      state = CommunityState(phase: CommunityPhase.failed, error: e.message);
    }
  }
}

final communityControllerProvider =
    NotifierProvider<CommunityController, CommunityState>(
      CommunityController.new,
    );
