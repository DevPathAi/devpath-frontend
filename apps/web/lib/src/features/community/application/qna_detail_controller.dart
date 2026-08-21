import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/community_source.dart';
import '../presentation/widgets/content_menu_button.dart';
import '../state/qna_detail_state.dart';

/// Q&A 상세 + 액션(답변·채택·투표). 액션은 모두 void/단건이라 성공 후 **상세를 재조회**해
/// 최신 답변 스레드·카운트·solved를 반영한다(설계서 §231 "GET /community/questions/{id} 재조회").
class QnaDetailController extends Notifier<QnaDetailState> {
  int? _id;

  /// 화면 전환 세대. ★id 비교만으로는 ABA(1→2→1)를 못 가른다★ — 같은 id 로 돌아오면
  /// 옛 뮤테이션이 "여전히 내 화면" 으로 오인하고 stale 스냅샷을 복원한다. load 마다
  /// 세대를 올려, await 뒤에는 id 와 세대가 모두 같을 때만 상태를 만진다(mobile 과 동일).
  int _generation = 0;

  @override
  QnaDetailState build() => const QnaLoading();

  Future<void> load(int id) async {
    _id = id;
    final gen = ++_generation;
    state = const QnaLoading();
    try {
      final detail = await ref.read(qnaDetailFetchProvider)(id);
      if (gen != _generation) return; // 그 사이 다른 load 가 시작됐다
      state = QnaLoaded(detail);
    } on ApiException catch (e) {
      if (gen != _generation) return;
      state = QnaFailed(e.message);
    }
  }

  /// 삭제 완료 콜백용 — ★보고 있는 질문일 때만★ 재조회한다. 메뉴 버튼의 삭제는 이
  /// 컨트롤러 밖(위젯)에서 완료되므로, 콜백이 도착한 시점엔 싱글턴 컨트롤러가 이미
  /// 다른 질문을 보고 있을 수 있다 — 그때 무조건 load 하면 남의 화면을 옛 질문으로 덮는다.
  Future<void> refreshIfShowing(int id) {
    if (_id != id) return Future.value();
    return load(id);
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
  /// ★성공 여부를 돌려준다★ — 카드가 성공했을 때만 에디터를 닫아야 한다. 실패했는데
  /// 닫으면, 재열기가 서버 본문으로 동기화하므로 사용자가 쓴 것을 되찾을 수 없다.
  ///
  /// 빈 본문은 서버를 부르지 않고 막는다. 서버도 400 을 내지만 왕복이 낭비다.
  Future<bool> updateAnswer(int answerId, String bodyMd) {
    final body = bodyMd.trim();
    if (body.isEmpty) return Future.value(false);
    return _mutate(
      () => ref.read(answerUpdateProvider)(answerId, body),
      messageFor: contentActionMessage,
    );
  }

  /// [messageFor] 를 주면 그 함수로 안내 문구를 만든다 — 수정·삭제는 서버 메시지 대신
  /// 스펙이 정한 전용 문구를 쓴다(기존 액션은 서버 메시지를 그대로 쓴다).
  ///
  /// @return 서버 뮤테이션의 성공 여부. 이동해서 화면을 안 만졌어도 성공은 성공이다.
  Future<bool> _mutate(
    Future<void> Function() action, {
    String Function(ApiException)? messageFor,
  }) async {
    final cur = state;
    if (cur is! QnaLoaded || _id == null) return false;
    // ★어느 질문·어느 세대에서 시작했는지 붙잡아 둔다★ — 이 프로바이더는 family 도
    // autoDispose 도 아닌 싱글턴이라 화면을 옮겨도 같은 인스턴스가 산다. await 뒤에는
    // 둘 다 같을 때만 상태를 만진다. id 만 보면 ABA(1→2→1)에서 옛 실패의 스냅샷이
    // 새로 읽은 화면을 덮는다(실측 red).
    final target = _id!;
    final gen = _generation;
    state = cur.copyWith(submitting: true);
    try {
      await action();
      if (_id != target || gen != _generation) return true;
      final fresh = await ref.read(qnaDetailFetchProvider)(target);
      if (_id != target || gen != _generation) return true;
      state = QnaLoaded(fresh);
      return true;
    } on ApiException catch (e) {
      if (_id != target || gen != _generation) return false;
      state = cur.copyWith(
        submitting: false,
        actionError: messageFor?.call(e) ?? e.message,
      );
      return false;
    }
  }
}

final qnaDetailControllerProvider =
    NotifierProvider<QnaDetailController, QnaDetailState>(
      QnaDetailController.new,
    );
