import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/community_source.dart';
import '../presentation/widgets/content_menu_button.dart';
import '../state/qna_detail_state.dart';

/// Q&A 상세 + 액션(답변·채택·투표). 액션은 모두 void/단건이라 성공 후 **상세를 재조회**해
/// 최신 답변 스레드·카운트·solved를 반영한다(설계서 §231 "GET /community/questions/{id} 재조회").
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

  /// 답변 수정(인라인). 성공하면 상세를 재조회한다 — 응답 하나로는 스레드 전체가
  /// 갱신되지 않는다(submitAnswer·accept 와 같은 방침).
  ///
  /// 빈 본문은 서버를 부르지 않고 막는다. 서버도 400 을 내지만 왕복이 낭비다.
  Future<void> updateAnswer(int answerId, String bodyMd) {
    final body = bodyMd.trim();
    if (body.isEmpty) return Future.value();
    return _mutate(
      () => ref.read(answerUpdateProvider)(answerId, body),
      messageFor: contentActionMessage,
    );
  }

  /// [messageFor] 를 주면 그 함수로 안내 문구를 만든다 — 수정·삭제는 서버 메시지 대신
  /// 스펙이 정한 전용 문구를 쓴다(기존 액션은 서버 메시지를 그대로 쓴다).
  Future<void> _mutate(
    Future<void> Function() action, {
    String Function(ApiException)? messageFor,
  }) async {
    final cur = state;
    if (cur is! QnaLoaded || _id == null) return;
    state = cur.copyWith(submitting: true);
    try {
      await action();
      final fresh = await ref.read(qnaDetailFetchProvider)(_id!);
      state = QnaLoaded(fresh);
    } on ApiException catch (e) {
      state = cur.copyWith(
        submitting: false,
        actionError: messageFor?.call(e) ?? e.message,
      );
    }
  }
}

final qnaDetailControllerProvider =
    NotifierProvider<QnaDetailController, QnaDetailState>(
      QnaDetailController.new,
    );
