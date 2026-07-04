import '../data/settings_models.dart';

/// 설정 화면 상태(sealed — presentation이 분기).
sealed class SettingsState {
  const SettingsState();
}

/// 초기/재조회 로딩.
class SettingsLoading extends SettingsState {
  const SettingsLoading();
}

/// 로드 완료: 동의 현황 + 알림 설정.
class SettingsReady extends SettingsState {
  const SettingsReady({required this.consents, required this.prefs});

  final ConsentsView consents;
  final NotificationPrefs prefs;
}

/// 로드/액션 실패.
class SettingsError extends SettingsState {
  const SettingsError(this.message);

  final String message;
}
