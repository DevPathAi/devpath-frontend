import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../../auth/state/auth_state.dart';
import '../../diagnostic/application/diagnostic_controller.dart';
import '../state/consent_state.dart';
import 'consent_source.dart';

class ConsentController extends Notifier<ConsentState> {
  @override
  ConsentState build() => const ConsentEditing();

  ConsentSource get _source => ref.read(consentSourceProvider);

  /// 동의 이력 + 생년을 제출한다. 성공 시 authController의 consentStatus를 DONE으로
  /// 갱신해 라우터 게이트가 /consent를 벗어나게 한다. 만 14세 미만이면 서버가
  /// 400 VALIDATION_FAILED를 던지며, 이를 [ConsentBlocked]로 매핑한다.
  Future<void> submit({
    required List<ConsentSubmitItem> items,
    required int birthYear,
  }) async {
    final submittingUserId = switch (ref.read(authControllerProvider)) {
      AuthAuthenticated(:final user) => user.id,
      _ => null,
    };
    state = const ConsentSubmitting();
    try {
      await _source.submit(items: items, birthYear: birthYear);
      final auth = ref.read(authControllerProvider);
      if (auth is! AuthAuthenticated ||
          submittingUserId == null ||
          auth.user.id != submittingUserId) {
        state = const ConsentError('로그인 계정이 바뀌어 동의 완료를 반영하지 않았어요. 다시 확인해 주세요.');
        ref
            .read(diagnosticControllerProvider.notifier)
            .markConsentFailure(
              '로그인 계정이 바뀌었어요. 진단 결과는 보존했으며 현재 계정에서 동의를 다시 확인해 주세요.',
            );
        return;
      }
      ref
          .read(authControllerProvider.notifier)
          .markConsentDone(
            auth.user.copyWith(consentStatus: ConsentStatus.done),
          );
      state = const ConsentDone();
    } on ApiException catch (e) {
      state = e.code == ApiErrorCode.validationFailed
          ? const ConsentBlocked()
          : ConsentError(e.message);
      ref
          .read(diagnosticControllerProvider.notifier)
          .markConsentFailure(
            e.code == ApiErrorCode.validationFailed
                ? '필수 동의를 완료하지 못했어요. 진단 결과는 이 탭에 남아 있으며 입력을 확인한 뒤 다시 시도할 수 있어요.'
                : '동의를 아직 저장하지 못했어요. 진단 결과는 이 탭에 그대로 남아 있어요.',
          );
    } catch (_) {
      const message = '동의를 저장하지 못했어요. 입력을 확인한 뒤 다시 시도해 주세요.';
      state = const ConsentError(message);
      ref
          .read(diagnosticControllerProvider.notifier)
          .markConsentFailure('동의를 아직 저장하지 못했어요. 진단 결과는 이 탭에 그대로 남아 있어요.');
    }
  }
}

final consentControllerProvider =
    NotifierProvider<ConsentController, ConsentState>(ConsentController.new);
