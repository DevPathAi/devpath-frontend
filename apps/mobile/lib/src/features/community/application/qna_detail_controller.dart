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

  /// 답변 수정(인라인). 성공하면 상세를 재조회한다.
  ///
  /// 빈 본문은 서버를 부르지 않고 막는다. 서버도 400 을 내지만 왕복이 낭비다.
  /// ★성공 여부를 돌려준다★ — web 과 같은 계약: 성공했을 때만 에디터를 닫는다.
  Future<bool> updateAnswer(int answerId, String bodyMd) {
    final body = bodyMd.trim();
    if (body.isEmpty) return Future.value(false);
    return _mutate(
      () => ref.read(answerUpdateProvider)(answerId, body),
      messageFor: _actionMessage,
    );
  }

  /// 답변 삭제(작성자). 채택된 답변이면 409 로 막힌다.
  Future<void> deleteAnswer(int answerId) => _mutate(
    () => ref.read(answerDeleteProvider)(answerId),
    messageFor: _actionMessage,
  );

  /// 수정·삭제 공통 문구. ★웹의 contentActionMessage 와 같은 문자열을 쓴다★ —
  /// 같은 서버 코드에 두 앱이 다른 말을 하면 안내가 갈린다. 패키지 경계를 넘지 않으려
  /// 복제하되, 문구가 갈리지 않도록 이 주석을 단다.
  String _actionMessage(ApiException e) => switch (e.code) {
    ApiErrorCode.forbidden => '내가 쓴 글만 수정할 수 있어요',
    ApiErrorCode.resourceNotFound => '이미 삭제된 콘텐츠예요',
    ApiErrorCode.conflict => '채택된 답변은 채택을 먼저 해제해 주세요',
    ApiErrorCode.validationFailed => '내용을 입력해 주세요',
    _ => '처리하지 못했어요. 잠시 후 다시 시도해 주세요',
  };

  /// [messageFor] 를 주면 그 함수로 안내 문구를 만든다 — 수정·삭제는 서버 메시지 대신
  /// 스펙이 정한 전용 문구를 쓴다(기존 액션은 서버 메시지를 그대로 쓴다).
  /// @return 서버 뮤테이션의 성공 여부. 이동해서 화면을 안 만졌어도 성공은 성공이다.
  Future<bool> _mutate(
    Future<void> Function() action, {
    String Function(ApiException)? messageFor,
  }) async {
    final cur = state;
    final id = _id;
    if (cur is! QnaLoaded || id == null) return false;
    final owner = _ownerKey;
    final generation = ++_generation;
    state = cur.copyWith(submitting: true);
    try {
      await action();
      if (!_isCurrent(owner, id, generation)) return true;
      final fresh = await ref.read(qnaDetailFetchProvider)(id);
      if (!_isCurrent(owner, id, generation)) return true;
      state = QnaLoaded(fresh);
      return true;
    } on ApiException catch (e) {
      if (!_isCurrent(owner, id, generation)) return false;
      state = cur.copyWith(
        submitting: false,
        actionError: messageFor?.call(e) ?? e.message,
      );
      return false;
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
