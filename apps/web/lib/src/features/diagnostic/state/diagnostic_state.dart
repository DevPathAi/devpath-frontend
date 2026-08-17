import 'package:dp_core/dp_core.dart';

import 'diagnostic_continuation.dart';

enum DiagnosticFailureKind {
  invalidContinuation,
  guestExpired,
  initialLoad,
  answer,
  oauth,
  consent,
  claim,
  ownership,
  resultMismatch,
  pathGeneration,
}

class DiagnosticFailure {
  const DiagnosticFailure(this.kind, this.message);

  final DiagnosticFailureKind kind;
  final String message;
}

enum DiagnosticPathBranch { unknown, newPath, existingActivePath }

const _unset = Object();

/// 진단에서 이미 유효한 데이터와 현재 mutation을 분리한다.
///
/// [preview]가 한 번 생긴 뒤에는 loading/error가 이를 대체하지 않는다.
class DiagnosticState {
  const DiagnosticState({
    this.phase = DiagnosticContinuationPhase.track,
    this.track,
    this.guestId,
    this.nextQuestion,
    this.preview,
    this.assessmentId,
    this.expiresAt,
    this.journeyId,
    this.saved = false,
    this.busy = false,
    this.failure,
    this.pathBranch = DiagnosticPathBranch.unknown,
    this.pathHandoffRequested = false,
    this.claimedOwnerUserId,
    this.pendingAnswer,
  });

  final DiagnosticContinuationPhase phase;
  final String? track;
  final String? guestId;
  final NextQuestion? nextQuestion;
  final AssessmentResult? preview;
  final int? assessmentId;
  final DateTime? expiresAt;
  final String? journeyId;
  final bool saved;
  final bool busy;
  final DiagnosticFailure? failure;
  final DiagnosticPathBranch pathBranch;

  /// 새 경로 CTA 이후부터 실제 path 생성 완료 전까지만 유지하는 메모리 상태다.
  ///
  /// continuation codec에는 넣지 않는다. 새로고침 시 saved preview로 안전하게
  /// 돌아가야 하며, 성공하지 않은 path 생성을 자동 재개하지 않는다.
  final bool pathHandoffRequested;

  /// 이 탭에서 claim/member completion을 확인한 auth identity. codec에는 넣지
  /// 않으며 reload/account switch에서는 DB-authoritative claim을 다시 검증한다.
  final String? claimedOwnerUserId;

  /// 마지막 answer mutation의 UI 선택. 재시도 중 표시만 하며 continuation에는
  /// 기록하지 않아 raw answer가 sessionStorage에 남지 않는다.
  final String? pendingAnswer;

  bool get hasPreview => preview != null;
  bool get hasContinuation => track != null;

  factory DiagnosticState.fromContinuation(DiagnosticContinuation value) =>
      DiagnosticState(
        phase: value.returnStage,
        track: value.track,
        guestId: value.guestId,
        preview: value.preview,
        expiresAt: value.expiresAt,
        journeyId: value.journeyId,
        saved: value.returnStage == DiagnosticContinuationPhase.saved,
      );

  DiagnosticState copyWith({
    DiagnosticContinuationPhase? phase,
    Object? track = _unset,
    Object? guestId = _unset,
    Object? nextQuestion = _unset,
    Object? preview = _unset,
    Object? assessmentId = _unset,
    Object? expiresAt = _unset,
    Object? journeyId = _unset,
    bool? saved,
    bool? busy,
    Object? failure = _unset,
    DiagnosticPathBranch? pathBranch,
    bool? pathHandoffRequested,
    Object? claimedOwnerUserId = _unset,
    Object? pendingAnswer = _unset,
  }) => DiagnosticState(
    phase: phase ?? this.phase,
    track: identical(track, _unset) ? this.track : track as String?,
    guestId: identical(guestId, _unset) ? this.guestId : guestId as String?,
    nextQuestion: identical(nextQuestion, _unset)
        ? this.nextQuestion
        : nextQuestion as NextQuestion?,
    preview: identical(preview, _unset)
        ? this.preview
        : preview as AssessmentResult?,
    assessmentId: identical(assessmentId, _unset)
        ? this.assessmentId
        : assessmentId as int?,
    expiresAt: identical(expiresAt, _unset)
        ? this.expiresAt
        : expiresAt as DateTime?,
    journeyId: identical(journeyId, _unset)
        ? this.journeyId
        : journeyId as String?,
    saved: saved ?? this.saved,
    busy: busy ?? this.busy,
    failure: identical(failure, _unset)
        ? this.failure
        : failure as DiagnosticFailure?,
    pathBranch: pathBranch ?? this.pathBranch,
    pathHandoffRequested: pathHandoffRequested ?? this.pathHandoffRequested,
    claimedOwnerUserId: identical(claimedOwnerUserId, _unset)
        ? this.claimedOwnerUserId
        : claimedOwnerUserId as String?,
    pendingAnswer: identical(pendingAnswer, _unset)
        ? this.pendingAnswer
        : pendingAnswer as String?,
  );
}
