import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/community_source.dart';
import '../state/qna_detail_state.dart';

/// Q&A 상세 + 액션(답변·채택·투표). 액션은 모두 void/단건이라 성공 후 **상세를 재조회**해
/// 최신 답변 스레드·카운트·solved를 반영한다(web QnaDetailController와 동일 정책).
class QnaDetailController extends Notifier<QnaDetailState> {
  int? _id;

  @override
  QnaDetailState build() => const QnaLoading();

  Future<void> load(int id) async {
    _id = id;
    state = const QnaLoading();
    try {
      final detail = await ref.read(qnaDetailFetchProvider)(id);
      state = QnaLoaded(detail);
    } on ApiException catch (e) {
      state = QnaFailed(e.message);
    }
  }

  /// 인간 답변 작성 → 스레드에 추가(재조회).
  Future<void> submitAnswer(String bodyMd) =>
      _mutate(() => ref.read(answerCreateProvider)(_id!, bodyMd));

  /// 답변 채택(질문자 OWNER). 비작성자면 백엔드 403 → [QnaLoaded.actionError]로 표면화.
  Future<void> accept(int answerId) =>
      _mutate(() => ref.read(answerAcceptProvider)(answerId));

  /// 게시글/답변 투표(UPSERT 집계).
  Future<void> vote(CommunityVoteTarget target, int targetId, int value) =>
      _mutate(
        () => ref.read(communityVoteProvider)(
          target: target,
          id: targetId,
          value: value,
        ),
      );

  Future<void> _mutate(Future<void> Function() action) async {
    final cur = state;
    if (cur is! QnaLoaded || _id == null) return;
    state = cur.copyWith(submitting: true);
    try {
      await action();
      final fresh = await ref.read(qnaDetailFetchProvider)(_id!);
      state = QnaLoaded(fresh);
    } on ApiException catch (e) {
      state = cur.copyWith(submitting: false, actionError: e.message);
    }
  }
}

final qnaDetailControllerProvider =
    NotifierProvider<QnaDetailController, QnaDetailState>(
      QnaDetailController.new,
    );
