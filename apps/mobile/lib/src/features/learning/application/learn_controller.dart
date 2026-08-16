import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/api_providers.dart';
import '../../auth/application/auth_controller.dart';
import '../state/learn_state.dart';

/// 학습 탭 — shared typed API에서 현재 경로를 읽어 뷰어 진입 목록을 구성.
class LearnController extends Notifier<LearnState> {
  String? _ownerKey;
  var _generation = 0;

  @override
  LearnState build() {
    _ownerKey = ref.read(currentOwnerKeyProvider);
    ref.listen(currentOwnerKeyProvider, (_, owner) {
      if (owner == _ownerKey) return;
      _ownerKey = owner;
      _generation += 1;
      state = const LearnLoading();
      if (owner != null) _scheduleLoad();
    });
    return const LearnLoading();
  }

  void _scheduleLoad() {
    final scheduledGeneration = _generation;
    Future<void>.microtask(() {
      if (ref.mounted && scheduledGeneration == _generation) {
        return load();
      }
    });
  }

  Future<void> load() async {
    final owner = _ownerKey;
    final generation = ++_generation;
    state = const LearnLoading();
    try {
      final path = await ref.read(learningPathApiProvider).currentPath();
      if (!_isCurrent(owner, generation)) return;
      state = LearnLoaded(path);
    } on ApiException catch (e) {
      if (!_isCurrent(owner, generation)) return;
      state = LearnFailed(e.message);
    }
  }

  bool _isCurrent(String? owner, int generation) =>
      ref.mounted && owner == _ownerKey && generation == _generation;
}

final learnControllerProvider = NotifierProvider<LearnController, LearnState>(
  LearnController.new,
);
