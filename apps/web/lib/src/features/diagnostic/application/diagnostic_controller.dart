import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/api_providers.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/state/auth_state.dart';
import '../state/diagnostic_state.dart';
import 'guest_claim_storage.dart';

final assessmentApiProvider = Provider<AssessmentApi>(
  (ref) => AssessmentApi(ref.read(apiClientProvider)),
);

final guestClaimStorageProvider = Provider<GuestClaimStorage>(
  (ref) => guestClaimStorage(),
);

class DiagnosticController extends Notifier<DiagnosticState> {
  @override
  DiagnosticState build() => const DiagnosticIdle();

  int? _assessmentId;
  String? _guestId;

  AssessmentApi get _api => ref.read(assessmentApiProvider);
  GuestClaimStorage get _storage => ref.read(guestClaimStorageProvider);

  bool get hasPendingGuestClaim => _storage.read() != null;

  Future<void> startAsMember(String track) async {
    state = const DiagnosticLoading();
    try {
      _assessmentId = await _api.startMember(track);
      _guestId = null;
      await _advance();
    } on ApiException catch (e) {
      state = DiagnosticError(e.message);
    }
  }

  Future<void> startAsGuest(String track) async {
    state = const DiagnosticLoading();
    try {
      _guestId = await _api.startGuest(track);
      _storage.write(_guestId!); // OAuth 리로드 생존
      _assessmentId = null;
      await _advance();
    } on ApiException catch (e) {
      state = DiagnosticError(e.message);
    }
  }

  Future<void> submitAnswer(
    int questionId,
    String answer, {
    int? timeSpentSec,
  }) => _answer(questionId, answer, false, timeSpentSec);

  Future<void> skip(int questionId) => _answer(questionId, null, true, null);

  Future<void> _answer(
    int questionId,
    String? answer,
    bool skipped,
    int? timeSpentSec,
  ) async {
    try {
      await _api.answer(
        assessmentId: _assessmentId,
        guestId: _guestId,
        questionId: questionId,
        answer: answer,
        skipped: skipped,
        timeSpentSec: timeSpentSec,
      );
      await _advance();
    } on ApiException catch (e) {
      state = DiagnosticError(e.message);
    }
  }

  Future<void> _advance() async {
    final next = await _api.next(
      assessmentId: _assessmentId,
      guestId: _guestId,
    );
    if (next != null) {
      state = DiagnosticQuestion(next);
      return;
    }
    final result = await _api.complete(
      assessmentId: _assessmentId,
      guestId: _guestId,
    );
    final authState = ref.read(authControllerProvider);
    final loggedIn = authState is AuthAuthenticated;
    if (_guestId != null && !loggedIn) {
      state = const DiagnosticGateSignup();
    } else {
      _storage.clear();
      // 인증 회원 완료 시 onboardingStatus를 DONE으로 갱신 → 게이트 해제.
      if (authState is AuthAuthenticated) {
        final updatedUser = authState.user.copyWith(
          onboardingStatus: OnboardingStatus.done,
        );
        ref
            .read(authControllerProvider.notifier)
            .onboardingCompleted(updatedUser);
      }
      state = DiagnosticResultState(result);
    }
  }

  /// 로그인 후 호출: 보관된 guestId로 결과를 회원에 귀속(claim) 후 result() 조회.
  Future<void> claimAfterLogin() async {
    final guestId = _storage.read();
    if (guestId == null) return;
    state = const DiagnosticLoading();
    try {
      _assessmentId = await _api.claim(guestId);
      final result = await _api.result(
        _assessmentId!,
      ); // complete() 아님(이미 COMPLETED)
      _guestId = null;
      _storage.clear();
      state = DiagnosticResultState(result);
    } on ApiException catch (e) {
      state = DiagnosticError(e.message);
    }
  }
}

final diagnosticControllerProvider =
    NotifierProvider<DiagnosticController, DiagnosticState>(
      DiagnosticController.new,
    );
