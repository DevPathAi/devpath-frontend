import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:devpath_web/src/features/auth/application/auth_controller.dart';
import 'package:devpath_web/src/features/auth/state/auth_state.dart';
import 'package:devpath_web/src/features/settings/application/settings_controller.dart';
import 'package:devpath_web/src/features/settings/application/settings_source.dart';
import 'package:devpath_web/src/features/settings/data/settings_models.dart';
import 'package:devpath_web/src/features/settings/state/settings_state.dart';

NotificationPrefs _prefs() => const NotificationPrefs(
  timezone: 'Asia/Seoul',
  preferredTimeSlot: '09:00',
  reminderEnabled: true,
  weeklyReportEmailEnabled: true,
);

ConsentsView _consents() => const ConsentsView(
  consentStatus: 'DONE',
  items: [
    ConsentItemView(type: 'TERMS', agreed: true, version: 'v1'),
    ConsentItemView(type: 'MARKETING', agreed: true, version: 'v1'),
  ],
  birthYear: 2000,
);

class _FakeSource implements SettingsSource {
  _FakeSource(this._p, this._c);
  NotificationPrefs _p;
  final ConsentsView _c;
  NotificationPrefs? lastUpdated;
  String? lastRevoked;
  bool deleteCalled = false;
  bool logoutCalled = false;

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
  @override
  Future<ConsentsView> fetchConsents() async => _c;
  @override
  Future<NotificationPrefs> fetchPrefs() async => _p;
  @override
  Future<NotificationPrefs> updatePrefs(NotificationPrefs prefs) async {
    lastUpdated = prefs;
    _p = prefs;
    return prefs;
  }

  @override
  Future<void> revokeConsent(String type) async => lastRevoked = type;
  @override
  Future<void> logout() async => logoutCalled = true;
  @override
  Future<void> deleteAccount() async => deleteCalled = true;
}

class _AuthedController extends AuthController {
  @override
  AuthState build() => const AuthAuthenticated(
    User(
      id: 'u',
      email: 'e@x.com',
      nickname: 'n',
      role: UserRole.learner,
      onboardingStatus: OnboardingStatus.done,
      consentStatus: ConsentStatus.done,
    ),
  );
}

ProviderContainer _container(_FakeSource source) {
  final container = ProviderContainer(
    overrides: [
      settingsSourceProvider.overrideWithValue(source),
      authControllerProvider.overrideWith(_AuthedController.new),
    ],
  );
  container.read(authControllerProvider); // authController 초기화
  return container;
}

void main() {
  test('load → SettingsReady(동의 현황 + 알림 설정)', () async {
    final container = _container(_FakeSource(_prefs(), _consents()));
    addTearDown(container.dispose);
    final notifier = container.read(settingsControllerProvider.notifier);

    await notifier.load();

    final state = container.read(settingsControllerProvider);
    expect(state, isA<SettingsReady>());
    final ready = state as SettingsReady;
    expect(ready.prefs.reminderEnabled, true);
    expect(ready.consents.consentStatus, 'DONE');
  });

  test('reminder 토글 → updatePrefs(PUT) 호출 + 상태 반영', () async {
    final source = _FakeSource(_prefs(), _consents());
    final container = _container(source);
    addTearDown(container.dispose);
    final notifier = container.read(settingsControllerProvider.notifier);
    await notifier.load();

    await notifier.setReminder(false);

    expect(source.lastUpdated, isNotNull);
    expect(source.lastUpdated!.reminderEnabled, false);
    // 전체 교체이므로 나머지 필드 유지
    expect(source.lastUpdated!.timezone, 'Asia/Seoul');
    expect(source.lastUpdated!.weeklyReportEmailEnabled, true);
    final ready = container.read(settingsControllerProvider) as SettingsReady;
    expect(ready.prefs.reminderEnabled, false);
  });

  test('선택 동의 철회 → revokeConsent 호출', () async {
    final source = _FakeSource(_prefs(), _consents());
    final container = _container(source);
    addTearDown(container.dispose);
    final notifier = container.read(settingsControllerProvider.notifier);
    await notifier.load();

    await notifier.revokeConsent('MARKETING');

    expect(source.lastRevoked, 'MARKETING');
  });

  test('계정 삭제 → deleteAccount 호출 + authController 미인증 전이', () async {
    final source = _FakeSource(_prefs(), _consents());
    final container = _container(source);
    addTearDown(container.dispose);
    final notifier = container.read(settingsControllerProvider.notifier);

    await notifier.deleteAccount();

    expect(source.deleteCalled, true);
    expect(container.read(authControllerProvider), isA<AuthUnauthenticated>());
  });

  test('로그아웃 → logout 호출 + authController 미인증 전이', () async {
    final source = _FakeSource(_prefs(), _consents());
    final container = _container(source);
    addTearDown(container.dispose);
    final notifier = container.read(settingsControllerProvider.notifier);

    await notifier.logout();

    expect(source.logoutCalled, true);
    expect(container.read(authControllerProvider), isA<AuthUnauthenticated>());
  });
}
