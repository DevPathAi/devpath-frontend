import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:devpath_web/src/features/diagnostic/application/diagnostic_controller.dart';
import 'package:devpath_web/src/features/diagnostic/application/guest_claim_storage.dart';
import 'package:devpath_web/src/features/diagnostic/state/diagnostic_state.dart';

class _FakeApi implements AssessmentApi {
  int _served = 0;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
  @override
  Future<String> startGuest(String track) async => 'g-1';
  @override
  Future<NextQuestion?> next({int? assessmentId, String? guestId}) async {
    if (_served >= 15) return null;
    _served++;
    return NextQuestion(
        question: const AssessmentQuestion(id: 1, type: 'MCQ', content: 'Q',
            options: null, bloomLevel: 'REMEMBER', difficulty: 0.3),
        index: _served, total: 15);
  }
  @override
  Future<void> answer({int? assessmentId, String? guestId, required int questionId,
      String? answer, required bool skipped, int? timeSpentSec}) async {}
  @override
  Future<AssessmentResult> complete({int? assessmentId, String? guestId}) async =>
      const AssessmentResult(diagnosedLevel: 'MID', confidenceWeight: 0.8);
}

class _FakeStorage implements GuestClaimStorage {
  String? _v;
  @override String? read() => _v;
  @override void write(String g) => _v = g;
  @override void clear() => _v = null;
}

void main() {
  test('guest 진단: 시작→15문항→완료→가입게이트', () async {
    final container = ProviderContainer(overrides: [
      assessmentApiProvider.overrideWithValue(_FakeApi()),
      guestClaimStorageProvider.overrideWithValue(_FakeStorage()),
    ]);
    addTearDown(container.dispose);
    final notifier = container.read(diagnosticControllerProvider.notifier);

    await notifier.startAsGuest('BACKEND_SPRING');
    var state = container.read(diagnosticControllerProvider);
    expect(state, isA<DiagnosticQuestion>());

    for (var i = 0; i < 15; i++) {
      await notifier.submitAnswer(1, '{"correct":0}');
    }
    state = container.read(diagnosticControllerProvider);
    expect(state, isA<DiagnosticGateSignup>()); // 미인증 guest 완료 → 가입게이트
  });
}
