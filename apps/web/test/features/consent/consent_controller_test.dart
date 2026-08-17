import 'dart:async';

import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:devpath_web/src/features/auth/application/auth_controller.dart';
import 'package:devpath_web/src/features/auth/state/auth_state.dart';
import 'package:devpath_web/src/features/consent/application/consent_controller.dart';
import 'package:devpath_web/src/features/consent/application/consent_source.dart';
import 'package:devpath_web/src/features/consent/state/consent_state.dart';
import 'package:devpath_web/src/features/diagnostic/application/diagnostic_controller.dart';
import 'package:devpath_web/src/features/diagnostic/state/diagnostic_continuation.dart';
import 'package:devpath_web/src/features/diagnostic/state/diagnostic_state.dart';

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

  void replace(AuthState next) => state = next;
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

class _NetworkSource implements ConsentSource {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);

  @override
  Future<void> submit({
    required List<ConsentSubmitItem> items,
    required int birthYear,
  }) async {
    throw const ApiException(
      code: ApiErrorCode.network,
      message: 'network unavailable',
    );
  }
}

class _MalformedSource implements ConsentSource {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);

  @override
  Future<void> submit({
    required List<ConsentSubmitItem> items,
    required int birthYear,
  }) async {
    throw const FormatException('raw malformed consent payload');
  }
}

class _GatedSource implements ConsentSource {
  final started = Completer<void>();
  final completed = Completer<void>();

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);

  @override
  Future<void> submit({
    required List<ConsentSubmitItem> items,
    required int birthYear,
  }) async {
    started.complete();
    await completed.future;
  }
}

class _RecordingDiagnosticController extends DiagnosticController {
  String? consentFailure;

  @override
  DiagnosticState build() => const DiagnosticState(
    phase: DiagnosticContinuationPhase.consent,
    track: 'BACKEND_SPRING',
    guestId: '123e4567-e89b-42d3-a456-426614174000',
    preview: AssessmentResult(diagnosedLevel: 'MID', confidenceWeight: 0.8),
  );

  @override
  void markConsentFailure(String message) => consentFailure = message;
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

  test('동의 제출 실패는 diagnostic preview continuation에 복구 오류를 남긴다', () async {
    final diagnostic = _RecordingDiagnosticController();
    final container = ProviderContainer(
      overrides: [
        consentSourceProvider.overrideWithValue(_NetworkSource()),
        authControllerProvider.overrideWith(_AuthedController.new),
        diagnosticControllerProvider.overrideWith(() => diagnostic),
      ],
    );
    addTearDown(container.dispose);
    container.read(authControllerProvider);

    await container
        .read(consentControllerProvider.notifier)
        .submit(
          items: const [
            (type: 'TERMS', agreed: true),
            (type: 'PRIVACY', agreed: true),
          ],
          birthYear: 2000,
        );

    expect(container.read(consentControllerProvider), isA<ConsentError>());
    expect(diagnostic.consentFailure, contains('결과'));
  });

  test('non-API 동의 실패도 submitting을 끝내고 sanitized retry 상태를 남긴다', () async {
    final diagnostic = _RecordingDiagnosticController();
    final container = ProviderContainer(
      overrides: [
        consentSourceProvider.overrideWithValue(_MalformedSource()),
        authControllerProvider.overrideWith(_AuthedController.new),
        diagnosticControllerProvider.overrideWith(() => diagnostic),
      ],
    );
    addTearDown(container.dispose);
    container.read(authControllerProvider);

    await container
        .read(consentControllerProvider.notifier)
        .submit(
          items: const [
            (type: 'TERMS', agreed: true),
            (type: 'PRIVACY', agreed: true),
          ],
          birthYear: 2000,
        );

    final state = container.read(consentControllerProvider);
    expect(state, isA<ConsentError>());
    expect((state as ConsentError).message, isNot(contains('raw malformed')));
    expect(diagnostic.consentFailure, contains('결과'));
  });

  test('동의 응답 대기 중 계정 전환은 새 계정을 DONE 처리하지 않는다', () async {
    final auth = _AuthedController();
    final source = _GatedSource();
    final diagnostic = _RecordingDiagnosticController();
    final container = ProviderContainer(
      overrides: [
        consentSourceProvider.overrideWithValue(source),
        authControllerProvider.overrideWith(() => auth),
        diagnosticControllerProvider.overrideWith(() => diagnostic),
      ],
    );
    addTearDown(container.dispose);
    container.read(authControllerProvider);
    final submission = container
        .read(consentControllerProvider.notifier)
        .submit(
          items: const [
            (type: 'TERMS', agreed: true),
            (type: 'PRIVACY', agreed: true),
          ],
          birthYear: 2000,
        );
    await source.started.future;
    auth.replace(AuthAuthenticated(_pendingUser().copyWith(id: 'other')));
    source.completed.complete();
    await submission;

    final current = container.read(authControllerProvider) as AuthAuthenticated;
    expect(current.user.id, 'other');
    expect(current.user.consentStatus, ConsentStatus.pending);
    expect(container.read(consentControllerProvider), isA<ConsentError>());
    expect(diagnostic.consentFailure, contains('계정'));
  });
}
