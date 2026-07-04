import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../data/settings_models.dart';
import '../state/settings_state.dart';
import 'settings_source.dart';

class SettingsController extends Notifier<SettingsState> {
  @override
  SettingsState build() => const SettingsLoading();

  SettingsSource get _source => ref.read(settingsSourceProvider);

  /// 동의 현황 + 알림 설정을 로드한다. 화면 진입/재조회 시 호출.
  Future<void> load() async {
    state = const SettingsLoading();
    try {
      final consents = await _source.fetchConsents();
      final prefs = await _source.fetchPrefs();
      state = SettingsReady(consents: consents, prefs: prefs);
    } on ApiException catch (e) {
      state = SettingsError(e.message);
    }
  }

  Future<void> setReminder(bool value) =>
      _patchPrefs((p) => p.copyWith(reminderEnabled: value));

  Future<void> setWeeklyEmail(bool value) =>
      _patchPrefs((p) => p.copyWith(weeklyReportEmailEnabled: value));

  /// 알림 토글: 낙관적 반영 후 PUT(전체 교체). 실패 시 이전 값으로 롤백.
  Future<void> _patchPrefs(
    NotificationPrefs Function(NotificationPrefs) update,
  ) async {
    final s = state;
    if (s is! SettingsReady) return;
    final previous = s.prefs;
    final target = update(previous);
    state = SettingsReady(consents: s.consents, prefs: target);
    try {
      final saved = await _source.updatePrefs(target);
      final cur = state;
      if (cur is SettingsReady) {
        state = SettingsReady(consents: cur.consents, prefs: saved);
      }
    } on ApiException {
      final cur = state;
      if (cur is SettingsReady) {
        state = SettingsReady(consents: cur.consents, prefs: previous);
      }
    }
  }

  /// 선택 동의 철회 후 현황 재조회. 필수 타입은 서버가 409(철회 불가).
  Future<void> revokeConsent(String type) async {
    if (state is! SettingsReady) return;
    try {
      await _source.revokeConsent(type);
      await load();
    } on ApiException catch (e) {
      state = SettingsError(e.message);
    }
  }

  /// 서버 세션 로그아웃 + 클라이언트 세션 정리(게이트 → /login).
  Future<void> logout() async {
    try {
      await _source.logout();
    } on ApiException {
      // 서버 로그아웃이 실패해도 클라이언트 세션은 정리한다.
    }
    await ref.read(authControllerProvider.notifier).logout();
  }

  /// 계정 soft-delete + 세션 정리(게이트 → /login).
  Future<void> deleteAccount() async {
    await _source.deleteAccount();
    await ref.read(authControllerProvider.notifier).logout();
  }
}

final settingsControllerProvider =
    NotifierProvider<SettingsController, SettingsState>(SettingsController.new);
