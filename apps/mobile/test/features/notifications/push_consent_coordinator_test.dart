import 'package:devpath_mobile/src/data/owner_data_store.dart';
import 'package:devpath_mobile/src/features/auth/state/auth_state.dart';
import 'package:devpath_mobile/src/features/notifications/application/device_registrar.dart';
import 'package:devpath_mobile/src/features/notifications/application/push_consent_coordinator.dart';
import 'package:devpath_mobile/src/services/push_service.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_test/flutter_test.dart';

final class _RecordingRegistrar extends DeviceRegistrar {
  _RecordingRegistrar()
    : super(
        ApiClient.create(const ApiConfig(baseUrl: 'https://api.test')),
        StubPushService(),
        'ANDROID',
        InMemoryOwnerDataStore(),
      );

  final events = <String>[];
  final credentialProofs = <bool?>[];
  var unregisterFailures = 0;

  @override
  Future<void> activate(String ownerKey) async {
    events.add('activate:$ownerKey');
  }

  @override
  Future<void> unregister(
    String ownerKey, {
    bool? credentialOwnerConfirmed,
  }) async {
    events.add('deactivate:$ownerKey');
    credentialProofs.add(credentialOwnerConfirmed);
    if (unregisterFailures > 0) {
      unregisterFailures -= 1;
      throw StateError('forced unregister failure');
    }
  }
}

User _user(String owner, ConsentStatus consent) => User(
  id: owner,
  email: '$owner@example.com',
  nickname: owner,
  role: UserRole.learner,
  onboardingStatus: OnboardingStatus.done,
  consentStatus: consent,
);

void main() {
  test(
    'cold verified PENDING revokes a durable registration exactly once',
    () async {
      final registrar = _RecordingRegistrar();
      final coordinator = PushConsentCoordinator(registrar);

      coordinator.handle(
        AuthAuthenticated(_user('owner-a', ConsentStatus.pending)),
      );
      coordinator.handle(
        AuthAuthenticated(_user('owner-a', ConsentStatus.pending)),
      );
      await coordinator.settled;

      expect(registrar.events, ['deactivate:owner-a']);
      expect(registrar.credentialProofs, [true]);
    },
  );

  test('DONE through Loading to PENDING deactivates once', () async {
    final registrar = _RecordingRegistrar();
    final coordinator = PushConsentCoordinator(registrar);

    coordinator.handle(AuthAuthenticated(_user('owner-a', ConsentStatus.done)));
    coordinator.handle(const AuthLoading());
    coordinator.handle(
      AuthAuthenticated(_user('owner-a', ConsentStatus.pending)),
    );
    await coordinator.settled;

    expect(registrar.events, ['activate:owner-a', 'deactivate:owner-a']);
  });

  test('DONE through Loading to DONE does not churn registration', () async {
    final registrar = _RecordingRegistrar();
    final coordinator = PushConsentCoordinator(registrar);

    coordinator.handle(AuthAuthenticated(_user('owner-a', ConsentStatus.done)));
    coordinator.handle(const AuthLoading());
    coordinator.handle(AuthAuthenticated(_user('owner-a', ConsentStatus.done)));
    await coordinator.settled;

    expect(registrar.events, ['activate:owner-a']);
  });

  test(
    'offline DONE stays active and online recovery activates once',
    () async {
      final registrar = _RecordingRegistrar();
      final coordinator = PushConsentCoordinator(registrar);

      coordinator.handle(
        AuthOfflineAuthenticated(
          _user('owner-a', ConsentStatus.done),
          'offline',
        ),
      );
      coordinator.handle(const AuthLoading());
      coordinator.handle(
        AuthAuthenticated(_user('owner-a', ConsentStatus.done)),
      );
      await coordinator.settled;

      expect(registrar.events, ['activate:owner-a']);
    },
  );

  test(
    'terminal logout is owned by AuthController and resume retries DONE',
    () async {
      final registrar = _RecordingRegistrar();
      final coordinator = PushConsentCoordinator(registrar);
      final done = AuthAuthenticated(_user('owner-a', ConsentStatus.done));

      coordinator.handle(done);
      coordinator.handle(const AuthUnauthenticated());
      coordinator.resume(done);
      await coordinator.settled;

      expect(registrar.events, ['activate:owner-a', 'activate:owner-a']);
    },
  );

  test(
    'failed non-DONE deactivation is retryable on state and resume',
    () async {
      final registrar = _RecordingRegistrar()..unregisterFailures = 1;
      final coordinator = PushConsentCoordinator(registrar);
      final pending = AuthAuthenticated(
        _user('owner-a', ConsentStatus.pending),
      );

      coordinator.handle(pending);
      await coordinator.settled;
      coordinator.handle(pending);
      await coordinator.settled;
      coordinator.resume(pending);
      await coordinator.settled;

      expect(registrar.events, [
        'deactivate:owner-a',
        'deactivate:owner-a',
        'deactivate:owner-a',
      ]);
    },
  );
}
