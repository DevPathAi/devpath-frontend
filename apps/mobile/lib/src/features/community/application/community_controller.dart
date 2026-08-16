import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../data/community_source.dart';
import '../state/community_state.dart';

/// 커뮤니티 탭 — 질문 목록(`GET /community/posts`).
class CommunityController extends Notifier<CommunityState> {
  String? _ownerKey;
  var _generation = 0;

  @override
  CommunityState build() {
    _ownerKey = ref.read(currentOwnerKeyProvider);
    ref.listen(currentOwnerKeyProvider, (_, owner) {
      if (owner == _ownerKey) return;
      _ownerKey = owner;
      _generation += 1;
      state = const CommunityLoading();
      if (owner != null) {
        Future<void>.microtask(load);
      }
    });
    return const CommunityLoading();
  }

  Future<void> load() async {
    final owner = _ownerKey;
    final generation = ++_generation;
    state = const CommunityLoading();
    try {
      final posts = await ref.read(communityListProvider)();
      if (!_isCurrent(owner, generation)) return;
      state = CommunityLoaded(posts);
    } on ApiException catch (e) {
      if (!_isCurrent(owner, generation)) return;
      state = CommunityFailed(e.message);
    }
  }

  bool _isCurrent(String? owner, int generation) =>
      ref.mounted && owner == _ownerKey && generation == _generation;
}

final communityControllerProvider =
    NotifierProvider<CommunityController, CommunityState>(
      CommunityController.new,
    );
