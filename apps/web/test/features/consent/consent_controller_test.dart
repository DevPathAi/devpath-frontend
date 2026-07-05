import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:devpath_web/src/features/auth/application/auth_controller.dart';
import 'package:devpath_web/src/features/auth/state/auth_state.dart';
import 'package:devpath_web/src/features/consent/application/consent_controller.dart';
import 'package:devpath_web/src/features/consent/application/consent_source.dart';
import 'package:devpath_web/src/features/consent/state/consent_state.dart';

User _pendingUser() => const User(
  id: 'u',
  email: 'e@x.com',
  nickname: 'n',
  role: UserRole.learner,
  onboardingStatus: OnboardingStatus.done,
  consentStatus: ConsentStatus.pending,
);

/// authController를 동의 미완(PENDING) 인증 상태로 고정하는 fake.
class _AuthedController extends AuthController {
  @override
  AuthState build() => AuthAuthenticated(_pendingUser());
}

/// 제출 성공 fake — 마지막 인자를 기록한다.
class _OkSource implements ConsentSource {
  List<ConsentSubmitItem>? lastItems;
  int? lastBirthYear;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
  @override
  Future<void> submit({
    required List<ConsentSubmitItem> items,
    required int birthYear,
  }) async {
    lastItems = items;
    lastBirthYear = birthYear;
  }
}

/// 만 14세 미만 → 서버 400 VALIDATION_FAILED를 던지는 fake.
class _MinorSource implements ConsentSource {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
  @override
  Future<void> submit({
    required List<ConsentSubmitItem> items,
    required int birthYear,
  }) async {
    throw const ApiException(
      code: ApiErrorCode.validationFailed,
      message: '만 14세 미만은 가입할 수 없습니다',
      status: 400,
    );
  }
}

void main() {
  test(
    '필수 동의 제출 성공 → ConsentDone + authController consentStatus=DONE',
    () async {
      final ok = _OkSource();
      final container = ProviderContainer(
        overrides: [
          consentSourceProvider.overrideWithValue(ok),
          authControllerProvider.overrideWith(_AuthedController.new),
        ],
      );
      addTearDown(container.dispose);
      container.read(authControllerProvider); // authController 초기화
      final notifier = container.read(consentControllerProvider.notifier);

      await notifier.submit(
        items: const [
          (type: 'TERMS', agreed: true),
          (type: 'PRIVACY', agreed: true),
          (type: 'MARKETING', agreed: false),
        ],
        birthYear: 2000,
      );

      expect(container.read(consentControllerProvider), isA<ConsentDone>());
      final auth = container.read(authControllerProvider);
      expect(
        (auth as AuthAuthenticated).user.consentStatus,
        ConsentStatus.done,
      );
      expect(ok.lastBirthYear, 2000);
      expect(ok.lastItems, hasLength(3));
    },
  );

  test('만 14세 미만(400 VALIDATION_FAILED) → ConsentBlocked, 동의 미완 유지', () async {
    final container = ProviderContainer(
      overrides: [
        consentSourceProvider.overrideWithValue(_MinorSource()),
        authControllerProvider.overrideWith(_AuthedController.new),
      ],
    );
    addTearDown(container.dispose);
    container.read(authControllerProvider);
    final notifier = container.read(consentControllerProvider.notifier);

    await notifier.submit(
      items: const [
        (type: 'TERMS', agreed: true),
        (type: 'PRIVACY', agreed: true),
      ],
      birthYear: 2020,
    );

    expect(container.read(consentControllerProvider), isA<ConsentBlocked>());
    final auth = container.read(authControllerProvider) as AuthAuthenticated;
    expect(auth.user.consentStatus, ConsentStatus.pending); // 차단 → 미완 유지
  });
}
