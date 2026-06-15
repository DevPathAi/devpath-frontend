import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/api_providers.dart';
import '../state/qna_detail_state.dart';

/// P4f-B: 다른 컨트롤러(Content·Dashboard·Path)와 동일한 plain Notifier + load(id) 패턴.
/// (riverpod 3.x family 베이스 클래스 불확실성 회피 + P4 일관성)
class QnaDetailController extends Notifier<QnaDetailState> {
  @override
  QnaDetailState build() => const QnaLoading();

  Future<void> load(String postId) async {
    state = const QnaLoading();
    try {
      final json = await ref
          .read(apiClientProvider)
          .get<Map<String, dynamic>>('/community/posts/$postId');
      state = QnaLoaded(CommunityPost.fromJson(json));
    } on ApiException catch (e) {
      state = QnaFailed(e.message);
    }
  }
}

final qnaDetailControllerProvider =
    NotifierProvider<QnaDetailController, QnaDetailState>(
      QnaDetailController.new,
    );
