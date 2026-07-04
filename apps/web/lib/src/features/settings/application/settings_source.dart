import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/api_providers.dart';
import '../data/settings_models.dart';

/// 설정 화면 API 배선: 동의 현황·철회(platform), 알림 설정(notification-svc),
/// 로그아웃·계정삭제(platform).
class SettingsSource {
  SettingsSource(this._client);

  final ApiClient _client;

  Future<ConsentsView> fetchConsents() async {
    final json = await _client.get<Map<String, dynamic>>('/consents/me');
    return ConsentsView.fromJson(json);
  }

  Future<NotificationPrefs> fetchPrefs() async {
    final json = await _client.get<Map<String, dynamic>>(
      '/notifications/prefs/me',
    );
    return NotificationPrefs.fromJson(json);
  }

  /// PUT은 4필드 전체 교체(누락 시 서버 400) — 호출부가 완전한 prefs를 넘긴다.
  Future<NotificationPrefs> updatePrefs(NotificationPrefs prefs) async {
    final json = await _client.put<Map<String, dynamic>>(
      '/notifications/prefs/me',
      body: prefs.toJson(),
    );
    return NotificationPrefs.fromJson(json);
  }

  /// 선택 동의 철회. 필수 타입은 서버가 409(ConsentRevokeConflictException).
  Future<void> revokeConsent(String type) =>
      _client.post<dynamic>('/consents/$type/revoke');

  Future<void> logout() => _client.post<dynamic>('/auth/logout');

  Future<void> deleteAccount() => _client.delete<dynamic>('/users/me');
}

final settingsSourceProvider = Provider<SettingsSource>(
  (ref) => SettingsSource(ref.read(apiClientProvider)),
);
