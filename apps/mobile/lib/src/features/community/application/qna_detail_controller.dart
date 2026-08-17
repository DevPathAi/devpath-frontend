import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../data/community_source.dart';
import '../state/qna_detail_state.dart';

/// Q&A 상세 + 액션(답변·채택·투표). 액션은 모두 void/단건이라 성공 후 **상세를 재조회**해
/// 최신 답변 스레드·카운트·solved를 반영한다(web QnaDetailController와 동일 정책).
class QnaDetailController extends Notifier<QnaDetailState> {
  int? _id;
  String? _ownerKey;
  var _generation = 0;

  @override
  QnaDetailState build() {
    _ownerKey = ref.read(currentOwnerKeyProvider);
    ref.listen(currentOwnerKeyProvider, (_, owner) {
      if (owner == _ownerKey) return;
      _ownerKey = owner;
      _generation += 1;
      state = const QnaLoading();
      final id = _id;
      if (owner != null && id != null) {
        Future<void>.microtask(() => load(id));
      }
    });
    return const QnaLoading();
  }

  Future<void> load(int id) async {
    _id = id;
    final owner = _ownerKey;
    final generation = ++_generation;
    state = const QnaLoading();
    try {
      final detail = await ref.read(qnaDetailFetchProvider)(id);
      if (!_isCurrent(owner, id, generation)) return;
      state = QnaLoaded(detail);
    } on ApiException catch (e) {
      if (!_isCurrent(owner, id, generation)) return;
      state = QnaFailed(e.message);
    }
  }

  void reset() {
    _id = null;
    _generation += 1;
    state = const QnaLoading();
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
    final id = _id;
    if (cur is! QnaLoaded || id == null) return;
    final owner = _ownerKey;
    final generation = ++_generation;
    state = cur.copyWith(submitting: true);
    try {
      await action();
      if (!_isCurrent(owner, id, generation)) return;
      final fresh = await ref.read(qnaDetailFetchProvider)(id);
      if (!_isCurrent(owner, id, generation)) return;
      state = QnaLoaded(fresh);
    } on ApiException catch (e) {
      if (!_isCurrent(owner, id, generation)) return;
      state = cur.copyWith(submitting: false, actionError: e.message);
    }
  }

  bool _isCurrent(String? owner, int id, int generation) =>
      ref.mounted &&
      owner == _ownerKey &&
      id == _id &&
      generation == _generation;
}

final qnaDetailControllerProvider =
    NotifierProvider<QnaDetailController, QnaDetailState>(
      QnaDetailController.new,
    );
