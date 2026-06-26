import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/api_providers.dart';
import '../state/learn_state.dart';

/// 학습 탭 — 학습 경로(`GET /learning-paths/me`)를 불러와 뷰어 진입 목록을 구성.
class LearnController extends Notifier<LearnState> {
  @override
  LearnState build() => const LearnLoading();

  Future<void> load() async {
    state = const LearnLoading();
    try {
      final json = await ref
          .read(apiClientProvider)
          .get<Map<String, dynamic>>('/learning-paths/me');
      state = LearnLoaded(LearningPath.fromJson(json));
    } on ApiException catch (e) {
      state = LearnFailed(e.message);
    }
  }
}

final learnControllerProvider = NotifierProvider<LearnController, LearnState>(
  LearnController.new,
);
