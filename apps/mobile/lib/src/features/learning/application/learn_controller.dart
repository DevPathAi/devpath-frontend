import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/api_providers.dart';
import '../state/learn_state.dart';

/// 학습 탭 — shared typed API에서 현재 경로를 읽어 뷰어 진입 목록을 구성.
class LearnController extends Notifier<LearnState> {
  @override
  LearnState build() => const LearnLoading();

  Future<void> load() async {
    state = const LearnLoading();
    try {
      final path = await ref.read(learningPathApiProvider).currentPath();
      state = LearnLoaded(path);
    } on ApiException catch (e) {
      state = LearnFailed(e.message);
    }
  }
}

final learnControllerProvider = NotifierProvider<LearnController, LearnState>(
  LearnController.new,
);
