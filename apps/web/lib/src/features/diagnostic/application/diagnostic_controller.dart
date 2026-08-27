import 'dart:async';
import 'dart:math' as math;

import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../analytics/journey_analytics.dart';
import '../../../analytics/journey_handoff.dart';
import '../../../analytics/path_analytics.dart';
import '../../../providers/api_providers.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/state/auth_state.dart';
import '../state/diagnostic_continuation.dart';
import '../state/diagnostic_state.dart';
import 'claim_analytics_receipt.dart';
import 'guest_claim_storage.dart';

final assessmentApiProvider = Provider<AssessmentApi>(
  (ref) => AssessmentApi(ref.read(apiClientProvider)),
);

final guestClaimStorageProvider = Provider<GuestClaimStorage>(
  (ref) => guestClaimStorage(),
);

final claimAnalyticsReceiptStoreProvider = Provider<ClaimAnalyticsReceiptStore>(
  (ref) => claimAnalyticsReceiptStore(),
);

final diagnosticClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

typedef DiagnosticCurrentPathProbe = Future<DiagnosticPathBranch> Function();

/// 기존 계약만 사용한다: 200은 active path, 404는 새 경로 생성 대상이다.
final diagnosticCurrentPathProbeProvider = Provider<DiagnosticCurrentPathProbe>(
  (ref) => () async {
    try {
      await ref
          .read(apiClientProvider)
          .get<Map<String, dynamic>>('/learning-paths/me');
      return DiagnosticPathBranch.existingActivePath;
    } on ApiException catch (error) {
      if (error.status == 404 || error.code == ApiErrorCode.resourceNotFound) {
        return DiagnosticPathBranch.newPath;
      }
      rethrow;
    }
  },
);

typedef _PendingAnswer = ({
  int questionId,
  String? answer,
  bool skipped,
  int? timeSpentSec,
});

const _continuationUnavailableFailure = DiagnosticFailure(
  DiagnosticFailureKind.invalidContinuation,
  '이 탭의 이어하기 정보를 준비하지 못했어요. 결과 화면을 닫지 말고 계속 진행해 주세요.',
);

class DiagnosticController extends Notifier<DiagnosticState> {
  AssessmentApi get _api => ref.read(assessmentApiProvider);
  GuestClaimStorage get _storage => ref.read(guestClaimStorageProvider);
  ClaimAnalyticsReceiptStore get _claimReceiptStore =>
      ref.read(claimAnalyticsReceiptStoreProvider);
  DateTime get _now => ref.read(diagnosticClockProvider)().toUtc();

  Future<void>? _claimFuture;
  Future<void>? _loginFuture;
  Future<bool>? _pathProbeFuture;
  Future<void>? _answerFuture;
  _PendingAnswer? _pendingAnswer;
  Object? _pendingAnswerError;
  bool _answerOutcomeUnknown = false;
  DateTime? _guestStartedAt;
  DateTime? _memberStartedAt;
  String? _memberOwnerUserId;
  String? _transientJourneyId;
  final Set<String> _capturedClaimKeys = <String>{};

  @override
  DiagnosticState build() {
    String? raw;
    try {
      raw = _storage.read();
    } catch (_) {
      return const DiagnosticState(
        failure: DiagnosticFailure(
          DiagnosticFailureKind.invalidContinuation,
          '이 탭에서 진단을 이어갈 수 없어 새로 시작해야 해요.',
        ),
      );
    }
    if (raw == null) return const DiagnosticState();

    final decoded = decodeDiagnosticContinuation(raw, now: _now);
    if (decoded.status == DiagnosticContinuationReadStatus.valid) {
      final continuation = decoded.value!;
      _guestStartedAt = continuation.diagnosticStartedAt;
      return DiagnosticState.fromContinuation(continuation);
    }
    _clearStorageBestEffort();
    return DiagnosticState(
      failure: DiagnosticFailure(
        decoded.status == DiagnosticContinuationReadStatus.expired
            ? DiagnosticFailureKind.guestExpired
            : DiagnosticFailureKind.invalidContinuation,
        decoded.status == DiagnosticContinuationReadStatus.expired
            ? '진단 결과 보관 시간이 지나 저장할 수 없어요. 다시 진단해 주세요.'
            : '저장된 진단 정보를 확인할 수 없어 안전하게 초기화했어요.',
      ),
    );
  }

  bool get hasPendingGuestClaim => state.guestId != null;
  bool get hasRestorableContinuation =>
      state.guestId != null || state.hasPreview;

  void selectTrack(String track) {
    final journeyId = _journeyId();
    state = DiagnosticState(
      phase: DiagnosticContinuationPhase.track,
      track: track,
      expiresAt: _now.add(diagnosticContinuationTtl),
      journeyId: journeyId,
      failure: journeyId == null ? _continuationUnavailableFailure : null,
    );
    _persist();
  }

  Future<void> startAsMember(String track) async {
    if (state.busy) return;
    _guestStartedAt = null;
    _memberStartedAt = _now;
    _memberOwnerUserId = switch (ref.read(authControllerProvider)) {
      AuthAuthenticated(:final user) => user.id,
      _ => null,
    };
    state = DiagnosticState(
      phase: DiagnosticContinuationPhase.track,
      track: track,
      busy: true,
    );
    try {
      final assessmentId = await _api.startMember(track);
      final memberOwnerUserId = _memberOwnerUserId;
      if (memberOwnerUserId == null ||
          !_isCurrentAuthenticatedUser(memberOwnerUserId)) {
        _finishOwnershipSwitch();
        return;
      }
      state = state.copyWith(
        phase: DiagnosticContinuationPhase.questions,
        assessmentId: assessmentId,
      );
      ref.read(journeyAnalyticsProvider).capture('diagnostic_started', {
        'track': track,
        'assessment_id': assessmentId,
      });
      await _advance();
    } catch (error) {
      _finishAdvanceFailure(error);
    }
  }

  Future<void> startAsGuest(String track) async {
    if (state.busy) return;
    _guestStartedAt = null;
    final journeyId = state.journeyId ?? _journeyId();
    state = DiagnosticState(
      phase: DiagnosticContinuationPhase.track,
      track: track,
      journeyId: journeyId,
      busy: true,
      failure: journeyId == null ? _continuationUnavailableFailure : null,
    );
    try {
      final guestId = await _api.startGuest(track);
      _guestStartedAt = _now;
      state = state.copyWith(
        phase: DiagnosticContinuationPhase.questions,
        guestId: guestId,
        expiresAt: _now.add(diagnosticContinuationTtl),
        busy: true,
        failure: null,
      );
      _persist();
      ref.read(journeyAnalyticsProvider).capture('diagnostic_started', {
        'track': track,
        'guest_id': guestId,
      });
      await _advance();
    } catch (error) {
      _finishAdvanceFailure(error);
    }
  }

  Future<void> submitAnswer(
    int questionId,
    String answer, {
    int? timeSpentSec,
  }) => _queueAnswer((
    questionId: questionId,
    answer: answer,
    skipped: false,
    timeSpentSec: timeSpentSec,
  ));

  Future<void> skip(int questionId) => _queueAnswer((
    questionId: questionId,
    answer: null,
    skipped: true,
    timeSpentSec: null,
  ));

  Future<void> retryLastAnswer() {
    final pending = _pendingAnswer;
    if (pending == null) return Future.value();
    final inFlight = _answerFuture;
    if (inFlight != null) return inFlight;
    if (!_answerOutcomeUnknown) return _queueAnswer(pending);

    late final Future<void> operation;
    operation =
        _reconcileAnswer(
          pending,
          _pendingAnswerError ?? StateError('answer outcome unavailable'),
        ).whenComplete(() {
          if (identical(_answerFuture, operation)) _answerFuture = null;
        });
    _answerFuture = operation;
    return operation;
  }

  Future<void> _queueAnswer(_PendingAnswer pending) {
    final inFlight = _answerFuture;
    if (inFlight != null) return inFlight;
    if (_expireIfNeeded()) return Future.value();
    _pendingAnswer = pending;
    _pendingAnswerError = null;
    _answerOutcomeUnknown = false;
    state = state.copyWith(pendingAnswer: pending.answer);
    late final Future<void> operation;
    operation = _answer(pending).whenComplete(() {
      if (identical(_answerFuture, operation)) _answerFuture = null;
    });
    _answerFuture = operation;
    return operation;
  }

  Future<void> _answer(_PendingAnswer pending) async {
    state = state.copyWith(busy: true, failure: null);
    try {
      await _api.answer(
        assessmentId: state.assessmentId,
        guestId: state.guestId,
        questionId: pending.questionId,
        answer: pending.answer,
        skipped: pending.skipped,
        timeSpentSec: pending.timeSpentSec,
      );
      if (!_isMemberAssessmentContextValid()) {
        _finishOwnershipSwitch();
        return;
      }
    } catch (error) {
      if (_isGuestExpiredError(error)) {
        _finishAnswerFailure(error);
        return;
      }
      _pendingAnswerError = error;
      _answerOutcomeUnknown = true;
      await _reconcileAnswer(pending, error);
      return;
    }

    if (state.guestId != null) {
      state = state.copyWith(expiresAt: _now.add(diagnosticContinuationTtl));
      _persist();
    }
    // answer 성공 뒤에는 동일 mutation을 다시 보내지 않는다. next/complete 실패는
    // 별도 advance retry로 복구한다.
    _clearPendingAnswer();
    try {
      await _advance();
    } catch (error) {
      _finishAdvanceFailure(error);
    }
  }

  Future<void> _advance() async {
    late final NextQuestion? next;
    try {
      next = await _api.next(
        assessmentId: state.assessmentId,
        guestId: state.guestId,
      );
    } catch (error) {
      if (await _recoverCommittedMemberResult()) return;
      Error.throwWithStackTrace(error, StackTrace.current);
    }
    if (!_isMemberAssessmentContextValid()) {
      _finishOwnershipSwitch();
      return;
    }
    await _applyNext(next);
  }

  Future<void> _applyNext(NextQuestion? next) async {
    if (next != null) {
      state = state.copyWith(
        phase: DiagnosticContinuationPhase.questions,
        nextQuestion: next,
        busy: false,
        failure: null,
      );
      if (state.guestId != null) _persist();
      return;
    }

    late final AssessmentResult result;
    try {
      result = await _api.complete(
        assessmentId: state.assessmentId,
        guestId: state.guestId,
      );
    } catch (error) {
      if (await _recoverCommittedMemberResult()) return;
      Error.throwWithStackTrace(error, StackTrace.current);
    }
    await _finishAssessment(result);
  }

  Future<void> _finishAssessment(AssessmentResult result) async {
    if (state.guestId != null) {
      state = state.copyWith(
        phase: DiagnosticContinuationPhase.preview,
        nextQuestion: null,
        preview: result,
        expiresAt: _now.add(diagnosticContinuationTtl),
        saved: false,
        busy: false,
        failure: null,
      );
      _persist();
      _captureGuestCompleted(result);
      return;
    }

    await _finishMemberAssessment(result);
  }

  Future<void> _finishMemberAssessment(AssessmentResult result) async {
    final memberOwnerUserId = _memberOwnerUserId;
    if (memberOwnerUserId == null ||
        !_isCurrentAuthenticatedUser(memberOwnerUserId)) {
      _finishOwnershipSwitch();
      return;
    }

    final elapsed = _now.difference(_memberStartedAt ?? _now).inMilliseconds;
    if (state.assessmentId case final assessmentId?) {
      ref.read(journeyAnalyticsProvider).capture('diagnostic_completed', {
        'assessment_id': assessmentId,
        'diagnosed_level': result.diagnosedLevel,
        'duration_ms': math.max(1, elapsed),
      });
    }
    state = state.copyWith(
      phase: DiagnosticContinuationPhase.saved,
      nextQuestion: null,
      preview: result,
      saved: true,
      busy: false,
      failure: null,
      claimedOwnerUserId: memberOwnerUserId,
    );
    final contextStillValid = await _probeCurrentPath(
      expectedOwnerUserId: memberOwnerUserId,
    );
    if (!contextStillValid ||
        !_isCurrentAuthenticatedUser(memberOwnerUserId) ||
        !_isSavedBoundToCurrentUser()) {
      _finishOwnershipSwitch();
      return;
    }
    // state에 saved preview를 먼저 세운 뒤 gate를 갱신해야 redirect race가 이를
    // /path로 덮지 않는다.
    _markOnboardingDone();
  }

  Future<bool> _recoverCommittedMemberResult() async {
    final assessmentId = state.assessmentId;
    final memberOwnerUserId = _memberOwnerUserId;
    if (assessmentId == null ||
        state.guestId != null ||
        memberOwnerUserId == null) {
      return false;
    }
    if (!_isCurrentAuthenticatedUser(memberOwnerUserId)) {
      _finishOwnershipSwitch();
      return true;
    }
    try {
      final result = await _api.result(assessmentId);
      if (!_isCurrentAuthenticatedUser(memberOwnerUserId)) {
        _finishOwnershipSwitch();
        return true;
      }
      await _finishMemberAssessment(result);
      return true;
    } catch (_) {
      if (!_isCurrentAuthenticatedUser(memberOwnerUserId)) {
        _finishOwnershipSwitch();
        return true;
      }
      return false;
    }
  }

  Future<void> _reconcileAnswer(
    _PendingAnswer pending,
    Object originalError,
  ) async {
    if (_expireIfNeeded()) return;
    state = state.copyWith(busy: true, failure: null);
    late final NextQuestion? next;
    try {
      next = await _api.next(
        assessmentId: state.assessmentId,
        guestId: state.guestId,
      );
    } catch (error) {
      if (_isGuestExpiredError(error)) {
        _finishAdvanceFailure(error);
        return;
      }
      _answerOutcomeUnknown = true;
      state = state.copyWith(
        busy: false,
        failure: const DiagnosticFailure(
          DiagnosticFailureKind.answer,
          '답변 저장 여부를 확인하지 못했어요. 상태 확인을 다시 시도해 주세요.',
        ),
      );
      return;
    }

    if (!_isMemberAssessmentContextValid()) {
      _finishOwnershipSwitch();
      return;
    }

    if (next?.question.id == pending.questionId) {
      // 서버가 같은 문항을 돌려준 경우에만 mutation 미적용이 확정된다.
      _answerOutcomeUnknown = false;
      _finishAnswerFailure(originalError);
      return;
    }

    // 다른 문항 또는 null이면 원 answer가 commit된 것이다. 다시 보내지 않는다.
    _clearPendingAnswer();
    try {
      await _applyNext(next);
    } catch (error) {
      _finishAdvanceFailure(error);
    }
  }

  void _clearPendingAnswer() {
    _pendingAnswer = null;
    _pendingAnswerError = null;
    _answerOutcomeUnknown = false;
    state = state.copyWith(pendingAnswer: null);
  }

  /// Reload/OAuth/consent 복귀에서 마지막 유효 단계만 재개한다.
  Future<void> resume() async {
    if (_expireIfNeeded()) return;
    switch (state.phase) {
      case DiagnosticContinuationPhase.track:
      case DiagnosticContinuationPhase.preview:
        return;
      case DiagnosticContinuationPhase.questions:
        if (state.busy) return;
        state = state.copyWith(busy: true, failure: null);
        try {
          await _advance();
        } catch (error) {
          _finishAdvanceFailure(error);
        }
      case DiagnosticContinuationPhase.auth:
        await _resumeAuthenticatedFlow();
      case DiagnosticContinuationPhase.consent:
        await _resumeAuthenticatedFlow();
      case DiagnosticContinuationPhase.claim:
        await _resumeAuthenticatedFlow();
      case DiagnosticContinuationPhase.saved:
        // codec에 user binding/assessmentId를 저장하지 않으므로 reload된 saved를
        // 현재 사용자 소유라고 신뢰하지 않는다. ET2 same-owner claim replay로
        // ownership과 결과를 다시 검증한 뒤에만 onboarding을 완료한다.
        if (state.guestId != null && !_isSavedBoundToCurrentUser()) {
          state = state.copyWith(
            phase: DiagnosticContinuationPhase.auth,
            assessmentId: null,
            saved: false,
            busy: false,
            failure: null,
            claimedOwnerUserId: null,
          );
          _persist();
          await _resumeAuthenticatedFlow();
          return;
        }
        if (state.assessmentId != null && !_isSavedBoundToCurrentUser()) {
          state = state.copyWith(
            saved: false,
            busy: false,
            failure: const DiagnosticFailure(
              DiagnosticFailureKind.ownership,
              '이 계정의 진단 결과가 아니어서 경로를 열지 않았어요.',
            ),
          );
          return;
        }
        if (state.pathBranch == DiagnosticPathBranch.unknown) {
          final ownerUserId = state.claimedOwnerUserId;
          final contextStillValid = await _probeCurrentPath(
            expectedOwnerUserId: ownerUserId,
          );
          if (!contextStillValid ||
              ownerUserId == null ||
              !_isCurrentAuthenticatedUser(ownerUserId)) {
            _finishOwnershipSwitch();
            return;
          }
        }
        _markOnboardingDone();
    }
  }

  /// start/answer는 재전송하지 않고 기존 assessment pointer로 next/complete만 재개한다.
  Future<void> retryAdvance() async {
    if (state.phase != DiagnosticContinuationPhase.questions || state.busy) {
      return;
    }
    await resume();
  }

  Future<void> saveAndContinue() async {
    final loginInFlight = _loginFuture;
    if (loginInFlight != null) {
      await loginInFlight;
      return;
    }
    if (!state.hasPreview || state.saved || state.busy || _expireIfNeeded()) {
      return;
    }
    final auth = ref.read(authControllerProvider);
    if (auth is! AuthAuthenticated) {
      late final Future<void> operation;
      operation = _launchOAuthHandoff().whenComplete(() {
        if (identical(_loginFuture, operation)) _loginFuture = null;
      });
      _loginFuture = operation;
      await operation;
      return;
    }
    if (auth.user.consentStatus != ConsentStatus.done) {
      state = state.copyWith(
        phase: DiagnosticContinuationPhase.consent,
        failure: null,
      );
      _persist();
      return;
    }
    await claimAfterLogin();
  }

  Future<void> _launchOAuthHandoff() async {
    final previewState = state;
    state = state.copyWith(
      phase: DiagnosticContinuationPhase.auth,
      busy: true,
      failure: null,
    );
    if (!_persist()) {
      final persistenceFailure = state.failure;
      state = previewState.copyWith(failure: persistenceFailure, busy: false);
      return;
    }
    try {
      await ref.read(authControllerProvider.notifier).login();
      // Full-page navigation normally takes over. If the launcher returns while
      // this page remains mounted, allow an explicit retry instead of locking it.
      if (ref.read(authControllerProvider) is! AuthAuthenticated &&
          state.phase == DiagnosticContinuationPhase.auth) {
        state = state.copyWith(busy: false);
      }
    } catch (_) {
      markOAuthFailure('로그인을 시작하지 못했어요. 결과는 이 탭에 남아 있어요.');
    }
  }

  Future<void> _resumeAuthenticatedFlow() async {
    final auth = ref.read(authControllerProvider);
    if (auth is! AuthAuthenticated) return;
    if (auth.user.consentStatus != ConsentStatus.done) {
      state = state.copyWith(
        phase: DiagnosticContinuationPhase.consent,
        busy: false,
      );
      _persist();
      return;
    }
    await claimAfterLogin();
  }

  /// ET2의 DB-authoritative same-owner replay 계약을 사용한다.
  Future<void> claimAfterLogin() {
    if (state.saved && _isSavedBoundToCurrentUser()) return Future.value();
    final inFlight = _claimFuture;
    if (inFlight != null) return inFlight;
    late final Future<void> operation;
    operation = _claim().whenComplete(() {
      if (identical(_claimFuture, operation)) _claimFuture = null;
    });
    _claimFuture = operation;
    return operation;
  }

  Future<void> _claim() async {
    if (!state.hasPreview || state.guestId == null || _expireIfNeeded()) return;
    final auth = ref.read(authControllerProvider);
    if (auth is! AuthAuthenticated) return;
    final claimUserId = auth.user.id;
    if (auth.user.consentStatus != ConsentStatus.done) {
      state = state.copyWith(phase: DiagnosticContinuationPhase.consent);
      _persist();
      return;
    }

    final originalPreview = state.preview!;
    state = state.copyWith(
      phase: DiagnosticContinuationPhase.claim,
      busy: true,
      failure: null,
    );
    _persist();
    late final int assessmentId;
    try {
      assessmentId = await _api.claim(state.guestId!);
    } on ApiException catch (error) {
      final kind = switch (error.code) {
        ApiErrorCode.forbidden => DiagnosticFailureKind.ownership,
        ApiErrorCode.resourceNotFound => DiagnosticFailureKind.guestExpired,
        _ when error.status == 403 => DiagnosticFailureKind.ownership,
        _ when error.status == 404 => DiagnosticFailureKind.guestExpired,
        _ => DiagnosticFailureKind.claim,
      };
      if (kind == DiagnosticFailureKind.guestExpired) {
        _expireGuestSession(_claimFailureMessage(kind));
      } else {
        state = state.copyWith(
          busy: false,
          failure: DiagnosticFailure(kind, _claimFailureMessage(kind)),
        );
        _persist();
      }
      return;
    } catch (_) {
      _finishClaimFailure();
      return;
    }
    if (!_isCurrentAuthenticatedUser(claimUserId)) {
      _finishOwnershipSwitch();
      return;
    }

    late final AssessmentResult savedResult;
    try {
      savedResult = await _api.result(assessmentId);
    } catch (_) {
      // assessmentId를 받은 뒤 result 확인만 실패한 경우 guest expiry로
      // 오분류하거나 continuation을 지우지 않는다. claim replay가 idempotent다.
      _finishClaimFailure();
      return;
    }
    if (!_isCurrentAuthenticatedUser(claimUserId)) {
      _finishOwnershipSwitch();
      return;
    }
    if (savedResult != originalPreview) {
      state = state.copyWith(
        busy: false,
        failure: const DiagnosticFailure(
          DiagnosticFailureKind.resultMismatch,
          '저장된 결과를 확인하지 못했어요. 화면의 결과는 그대로 보존했어요.',
        ),
      );
      _persist();
      return;
    }

    state = state.copyWith(
      phase: DiagnosticContinuationPhase.saved,
      assessmentId: assessmentId,
      preview: originalPreview,
      expiresAt: _now.add(diagnosticContinuationTtl),
      saved: true,
      busy: false,
      failure: null,
      claimedOwnerUserId: claimUserId,
    );
    _persist();
    final contextStillValid = await _probeCurrentPath(
      expectedOwnerUserId: claimUserId,
    );
    if (!contextStillValid ||
        !_isCurrentAuthenticatedUser(claimUserId) ||
        !_isSavedBoundToCurrentUser()) {
      _finishOwnershipSwitch();
      return;
    }
    _markOnboardingDone();
  }

  Future<void> retryPathProbe() async {
    await _probeCurrentPath(expectedOwnerUserId: state.claimedOwnerUserId);
  }

  Future<bool> _probeCurrentPath({String? expectedOwnerUserId}) {
    final inFlight = _pathProbeFuture;
    if (inFlight != null) return inFlight;
    late final Future<bool> operation;
    operation = _performPathProbe(expectedOwnerUserId: expectedOwnerUserId)
        .whenComplete(() {
          if (identical(_pathProbeFuture, operation)) _pathProbeFuture = null;
        });
    _pathProbeFuture = operation;
    return operation;
  }

  Future<bool> _performPathProbe({String? expectedOwnerUserId}) async {
    final ownerUserId = expectedOwnerUserId ?? state.claimedOwnerUserId;
    if (!state.saved ||
        state.busy ||
        ownerUserId == null ||
        !_isCurrentAuthenticatedUser(ownerUserId) ||
        state.claimedOwnerUserId != ownerUserId) {
      return false;
    }
    state = state.copyWith(
      busy: true,
      failure: null,
      pathBranch: DiagnosticPathBranch.unknown,
      pathHandoffRequested: false,
    );
    try {
      final branch = await ref.read(diagnosticCurrentPathProbeProvider)();
      if (!_isPathProbeContextValid(ownerUserId)) return false;
      state = state.copyWith(pathBranch: branch, busy: false, failure: null);
      if (state.guestId != null) _persist();
      _captureClaimOutcome();
      return true;
    } on ApiException catch (_) {
      if (!_isPathProbeContextValid(ownerUserId)) return false;
      state = state.copyWith(
        busy: false,
        failure: const DiagnosticFailure(
          DiagnosticFailureKind.pathGeneration,
          '결과는 저장됐지만 학습 경로 상태를 불러오지 못했어요.',
        ),
      );
      if (state.guestId != null) _persist();
      return true;
    } catch (_) {
      if (!_isPathProbeContextValid(ownerUserId)) return false;
      state = state.copyWith(
        busy: false,
        failure: const DiagnosticFailure(
          DiagnosticFailureKind.pathGeneration,
          '결과는 저장됐지만 학습 경로 상태를 불러오지 못했어요.',
        ),
      );
      if (state.guestId != null) _persist();
      return true;
    }
  }

  void markOAuthFailure(String message) {
    if (!state.hasPreview || state.saved) return;
    state = state.copyWith(
      phase: DiagnosticContinuationPhase.auth,
      busy: false,
      failure: DiagnosticFailure(DiagnosticFailureKind.oauth, message),
    );
    _persist();
  }

  void markConsentFailure(String message) {
    if (!state.hasPreview || state.saved) return;
    state = state.copyWith(
      phase: DiagnosticContinuationPhase.consent,
      busy: false,
      failure: DiagnosticFailure(DiagnosticFailureKind.consent, message),
    );
    _persist();
  }

  void completePathHandoff() {
    if (!state.saved || state.busy) return;
    _stagePathAnalyticsHandoff();
    if (state.pathBranch == DiagnosticPathBranch.newPath) {
      state = state.copyWith(pathHandoffRequested: true, failure: null);
      return;
    }
    if (state.pathBranch != DiagnosticPathBranch.existingActivePath) return;
    _clearAfterSuccessfulHandoff();
  }

  void _stagePathAnalyticsHandoff() {
    final auth = ref.read(authControllerProvider);
    if (auth is! AuthAuthenticated ||
        state.claimedOwnerUserId != auth.user.id ||
        state.pathBranch == DiagnosticPathBranch.unknown) {
      return;
    }
    ref
        .read(pathAnalyticsHandoffStoreProvider)
        .stage(
          PathAnalyticsHandoff(
            branch: state.pathBranch == DiagnosticPathBranch.newPath
                ? PathAnalyticsBranch.generated
                : PathAnalyticsBranch.existing,
            userId: auth.user.id,
            assessmentId: state.assessmentId,
            guestId: state.guestId,
          ),
        );
  }

  /// 새 경로 생성 완료가 확인된 뒤에만 continuation을 지운다.
  void completeSuccessfulPathHandoff() {
    if (!state.saved ||
        state.pathBranch != DiagnosticPathBranch.newPath ||
        !state.pathHandoffRequested) {
      return;
    }
    _clearAfterSuccessfulHandoff();
  }

  void markPathGenerationFailure(String? message) {
    if (!state.saved ||
        state.pathBranch != DiagnosticPathBranch.newPath ||
        !state.pathHandoffRequested) {
      return;
    }
    state = state.copyWith(
      busy: false,
      failure: DiagnosticFailure(
        DiagnosticFailureKind.pathGeneration,
        message?.trim().isNotEmpty == true
            ? message!
            : '결과는 저장됐지만 학습 경로를 아직 만들지 못했어요.',
      ),
    );
    if (state.guestId != null) _persist();
  }

  void _clearAfterSuccessfulHandoff() {
    _clearStorageBestEffort();
    state = const DiagnosticState();
  }

  void restart() {
    _clearStorageBestEffort();
    _pendingAnswer = null;
    _pendingAnswerError = null;
    _answerOutcomeUnknown = false;
    _guestStartedAt = null;
    _memberOwnerUserId = null;
    state = const DiagnosticState();
  }

  void _markOnboardingDone() {
    final auth = ref.read(authControllerProvider);
    if (auth is AuthAuthenticated &&
        state.saved &&
        state.claimedOwnerUserId == auth.user.id &&
        auth.user.onboardingStatus != OnboardingStatus.done) {
      ref
          .read(authControllerProvider.notifier)
          .onboardingCompleted(
            auth.user.copyWith(onboardingStatus: OnboardingStatus.done),
          );
    }
  }

  void _finishAdvanceFailure(Object error) {
    if (_isGuestExpiredError(error)) {
      _expireGuestSession('진단 결과의 30분 보관 시간이 지났어요. 다시 진단해 주세요.');
      return;
    }
    state = state.copyWith(
      busy: false,
      failure: DiagnosticFailure(
        DiagnosticFailureKind.initialLoad,
        error is ApiException ? error.message : '진단 정보를 확인하지 못했어요. 다시 시도해 주세요.',
      ),
    );
    if (state.guestId != null) _persist();
  }

  void _finishAnswerFailure(Object error) {
    if (_isGuestExpiredError(error)) {
      _expireGuestSession('진단 결과의 30분 보관 시간이 지났어요. 다시 진단해 주세요.');
      return;
    }
    state = state.copyWith(
      busy: false,
      failure: DiagnosticFailure(
        DiagnosticFailureKind.answer,
        error is ApiException
            ? error.message
            : '답변을 저장하지 못했어요. 같은 답변으로 다시 시도해 주세요.',
      ),
    );
  }

  void _finishClaimFailure() {
    state = state.copyWith(
      busy: false,
      saved: false,
      failure: const DiagnosticFailure(
        DiagnosticFailureKind.claim,
        '결과를 아직 저장하지 못했어요. 화면의 결과는 그대로이며 다시 시도할 수 있어요.',
      ),
    );
    _persist();
  }

  void _finishOwnershipSwitch() {
    if (state.guestId == null) {
      state = DiagnosticState(
        phase: DiagnosticContinuationPhase.track,
        track: state.track,
        failure: const DiagnosticFailure(
          DiagnosticFailureKind.ownership,
          '로그인 계정이 바뀌어 이 진단을 중단했어요. 현재 계정에서 다시 시작해 주세요.',
        ),
      );
      return;
    }
    state = state.copyWith(
      phase: DiagnosticContinuationPhase.auth,
      assessmentId: null,
      saved: false,
      busy: false,
      claimedOwnerUserId: null,
      failure: const DiagnosticFailure(
        DiagnosticFailureKind.ownership,
        '로그인 계정이 바뀌어 결과 연결을 중단했어요. 현재 계정으로 다시 확인해 주세요.',
      ),
    );
    _persist();
  }

  bool _isGuestExpiredError(Object error) =>
      state.guestId != null &&
      error is ApiException &&
      (error.code == ApiErrorCode.resourceNotFound || error.status == 404);

  bool _isCurrentAuthenticatedUser(String userId) =>
      switch (ref.read(authControllerProvider)) {
        AuthAuthenticated(:final user) => user.id == userId,
        _ => false,
      };

  bool _isMemberAssessmentContextValid() =>
      state.assessmentId == null ||
      state.guestId != null ||
      (_memberOwnerUserId != null &&
          _isCurrentAuthenticatedUser(_memberOwnerUserId!));

  bool _isSavedBoundToCurrentUser() =>
      state.assessmentId != null &&
      state.claimedOwnerUserId != null &&
      _isCurrentAuthenticatedUser(state.claimedOwnerUserId!);

  bool _isPathProbeContextValid(String ownerUserId) =>
      state.saved &&
      state.claimedOwnerUserId == ownerUserId &&
      _isCurrentAuthenticatedUser(ownerUserId);

  void _captureClaimOutcome() {
    if (!state.saved ||
        state.guestId == null ||
        state.assessmentId == null ||
        state.pathBranch == DiagnosticPathBranch.unknown ||
        !_isSavedBoundToCurrentUser()) {
      return;
    }
    final auth = ref.read(authControllerProvider) as AuthAuthenticated;
    final captureKey = '${state.guestId}|${state.assessmentId}|${auth.user.id}';
    String? receiptId;
    try {
      receiptId = claimAnalyticsReceiptId(
        guestId: state.guestId!,
        assessmentId: state.assessmentId!,
        userId: auth.user.id,
      );
      if (_claimReceiptStore.contains(receiptId)) return;
    } catch (_) {
      // Analytics persistence is best-effort and never blocks the saved UI.
    }
    if (!_capturedClaimKeys.add(receiptId ?? captureKey)) return;
    final status = ref
        .read(journeyAnalyticsProvider)
        .capture('result_claimed', {
          'guest_id': state.guestId!,
          'assessment_id': state.assessmentId!,
          'user_id': auth.user.id,
          'claim_outcome': state.pathBranch == DiagnosticPathBranch.newPath
              ? 'new_path_eligible'
              : 'existing_active_path',
        });
    if (receiptId != null &&
        (status == AnalyticsCaptureStatus.accepted ||
            status == AnalyticsCaptureStatus.duplicate)) {
      try {
        _claimReceiptStore.record(receiptId);
      } catch (_) {
        // sessionStorage denial cannot roll back a successful claim.
      }
    }
  }

  void _captureGuestCompleted(AssessmentResult result) {
    final startedAt = _guestStartedAt;
    final guestId = state.guestId;
    if (startedAt == null || guestId == null) return;
    _guestStartedAt = null;
    final elapsed = _now.difference(startedAt).inMilliseconds;
    try {
      ref.read(journeyAnalyticsProvider).capture('diagnostic_completed', {
        'guest_id': guestId,
        'diagnosed_level': result.diagnosedLevel,
        'duration_ms': math.max(1, elapsed),
      });
    } catch (_) {
      // Analytics delivery must not prevent rendering the completed preview.
    }
  }

  void _expireGuestSession(String message) {
    _clearStorageBestEffort();
    _pendingAnswer = null;
    _pendingAnswerError = null;
    _answerOutcomeUnknown = false;
    _guestStartedAt = null;
    final failure = DiagnosticFailure(
      DiagnosticFailureKind.guestExpired,
      message,
    );
    if (state.preview case final preview?) {
      state = DiagnosticState(
        phase: DiagnosticContinuationPhase.preview,
        track: state.track,
        preview: preview,
        journeyId: state.journeyId,
        failure: failure,
      );
      return;
    }
    state = DiagnosticState(track: state.track, failure: failure);
  }

  bool _expireIfNeeded() {
    final expiresAt = state.expiresAt;
    if (expiresAt == null || _now.isBefore(expiresAt)) return false;
    _expireGuestSession(
      '30분의 보관 시간이 지나 결과를 저장할 수 없어요. 화면의 결과를 확인한 뒤 다시 진단해 주세요.',
    );
    return true;
  }

  bool _persist() {
    if (state.track == null) return true;
    if (state.journeyId == null) {
      if (state.failure == null) {
        state = state.copyWith(failure: _continuationUnavailableFailure);
      }
      return false;
    }
    if (state.phase != DiagnosticContinuationPhase.track &&
        state.guestId == null) {
      return true; // member 진단은 guest continuation 대상이 아니다.
    }
    final expiresAt = state.expiresAt;
    if (expiresAt == null) return true;
    try {
      _storage.write(
        encodeDiagnosticContinuation(
          DiagnosticContinuation(
            guestId: state.guestId,
            track: state.track!,
            preview: state.preview,
            diagnosticStartedAt: _guestStartedAt,
            expiresAt: expiresAt,
            returnStage: state.phase,
            journeyId: state.journeyId!,
          ),
        ),
      );
      return true;
    } catch (_) {
      // 현재 화면 데이터는 유지한다. reload continuation만 사용할 수 없다.
      if (state.failure == null) {
        state = state.copyWith(
          failure: const DiagnosticFailure(
            DiagnosticFailureKind.invalidContinuation,
            '이 탭의 이어하기 정보를 저장하지 못했어요. 결과 화면을 닫지 말고 다시 시도해 주세요.',
          ),
        );
      }
      return false;
    }
  }

  String? _journeyId() {
    final transient = _transientJourneyId;
    if (isValidJourneyId(transient)) return transient;
    final store = ref.read(journeyIdStoreProvider);
    String? existing;
    try {
      existing = store.read();
    } catch (_) {
      existing = null;
    }
    if (isValidJourneyId(existing)) return existing!;
    String? created;
    try {
      created = ref.read(analyticsIdGeneratorProvider)();
    } catch (_) {
      return null;
    }
    if (!isValidJourneyId(created)) return null;
    _transientJourneyId = created;
    try {
      store.write(created);
    } catch (_) {
      // Keep the valid ID in memory. Core diagnostic remains usable even when
      // sessionStorage is unavailable.
    }
    return created;
  }

  void _clearStorageBestEffort() {
    try {
      _storage.clear();
    } catch (_) {}
  }
}

String _claimFailureMessage(DiagnosticFailureKind kind) => switch (kind) {
  DiagnosticFailureKind.ownership =>
    '이 결과를 현재 계정에 저장할 수 없어요. 다른 계정의 결과는 연결하지 않습니다.',
  DiagnosticFailureKind.guestExpired =>
    '진단 결과의 30분 보관 시간이 지났어요. 화면의 결과는 확인할 수 있지만 저장하려면 다시 진단해야 해요.',
  _ => '결과를 아직 저장하지 못했어요. 화면의 결과는 그대로이며 다시 시도할 수 있어요.',
};

final diagnosticControllerProvider =
    NotifierProvider<DiagnosticController, DiagnosticState>(
      DiagnosticController.new,
    );
