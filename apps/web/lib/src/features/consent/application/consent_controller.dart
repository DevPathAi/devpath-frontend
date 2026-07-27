import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../../auth/state/auth_state.dart';
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
    state = const ConsentSubmitting();
    try {
      await _source.submit(items: items, birthYear: birthYear);
      final auth = ref.read(authControllerProvider);
      if (auth is AuthAuthenticated) {
        ref
            .read(authControllerProvider.notifier)
            .markConsentDone(
              auth.user.copyWith(consentStatus: ConsentStatus.done),
            );
      }
      state = const ConsentDone();
    } on ApiException catch (e) {
      state = e.code == ApiErrorCode.validationFailed
          ? const ConsentBlocked()
          : ConsentError(e.message);
    }
  }
}

final consentControllerProvider =
    NotifierProvider<ConsentController, ConsentState>(ConsentController.new);
