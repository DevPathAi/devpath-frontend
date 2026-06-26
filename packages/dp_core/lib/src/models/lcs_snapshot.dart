import 'package:freezed_annotation/freezed_annotation.dart';

part 'lcs_snapshot.freezed.dart';
part 'lcs_snapshot.g.dart';

/// LCS(학습 맥락 자동 첨부) 모델 — gateway `/lcs/**` → lcs-svc(MD3 슬라이스 #9).
///
/// [LcsDraft]는 질문 작성 폼의 맥락 카드(미리보기), [LcsSnapshotView]는 질문 상세의
/// 답변자 맥락 패널에서 쓴다. [content]는 서버 조립 결과(불변 JSON)로 필드 구성이
/// 가변적이라 `Map`으로 받는다(키: `current_content`·`recent_activity` 등).

/// 조립 불가 필드(사유). reason 예: `user_preference_off`·`no_content_context`·
/// `source_unavailable`·`phase2_deferred`.
@freezed
abstract class LcsFieldUnavailable with _$LcsFieldUnavailable {
  const factory LcsFieldUnavailable({
    required String field,
    required String reason,
  }) = _LcsFieldUnavailable;

  factory LcsFieldUnavailable.fromJson(Map<String, dynamic> json) =>
      _$LcsFieldUnavailableFromJson(json);
}

/// 미리보기 조립 결과(`POST /lcs/snapshots/draft`). [draftId]는 Redis TTL 10분.
/// 게시 후 `POST /lcs/snapshots/{draftId}/commit`으로 영속한다.
@freezed
abstract class LcsDraft with _$LcsDraft {
  const factory LcsDraft({
    required String draftId,
    required DateTime expiresAt,
    @Default(<String, dynamic>{}) Map<String, dynamic> content,
    @Default(<String>[]) List<String> fieldsAvailable,
    @Default(<LcsFieldUnavailable>[])
    List<LcsFieldUnavailable> fieldsUnavailable,
  }) = _LcsDraft;

  factory LcsDraft.fromJson(Map<String, dynamic> json) =>
      _$LcsDraftFromJson(json);
}

/// 답변자 맥락 조회 결과(`GET /lcs/snapshots/{id}` · `.../by-question/{questionId}`).
/// renderedFor = "answerer".
@freezed
abstract class LcsSnapshotView with _$LcsSnapshotView {
  const factory LcsSnapshotView({
    required int id,
    required DateTime createdAt,
    @Default(<String, dynamic>{}) Map<String, dynamic> content,
    @Default('answerer') String renderedFor,
  }) = _LcsSnapshotView;

  factory LcsSnapshotView.fromJson(Map<String, dynamic> json) =>
      _$LcsSnapshotViewFromJson(json);
}
