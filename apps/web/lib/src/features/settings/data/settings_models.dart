/// GET /consents/me 응답(platform ConsentStatusView).
class ConsentsView {
  const ConsentsView({
    required this.consentStatus,
    required this.items,
    this.birthYear,
  });

  final String consentStatus;
  final List<ConsentItemView> items;
  final int? birthYear;

  factory ConsentsView.fromJson(Map<String, dynamic> json) => ConsentsView(
    consentStatus: json['consentStatus'] as String? ?? 'PENDING',
    items: [
      for (final it in (json['items'] as List? ?? const []))
        ConsentItemView.fromJson((it as Map).cast<String, dynamic>()),
    ],
    birthYear: (json['birthYear'] as num?)?.toInt(),
  );

  ConsentItemView? itemOf(String type) {
    for (final it in items) {
      if (it.type == type) return it;
    }
    return null;
  }
}

/// 동의 항목 현황(type=백엔드 ConsentType 문자열).
class ConsentItemView {
  const ConsentItemView({
    required this.type,
    required this.agreed,
    required this.version,
    this.agreedAt,
  });

  final String type;
  final bool agreed;
  final String version;
  final String? agreedAt;

  factory ConsentItemView.fromJson(Map<String, dynamic> json) =>
      ConsentItemView(
        type: json['type'] as String,
        agreed: json['agreed'] as bool? ?? false,
        version: json['version'] as String? ?? '',
        agreedAt: json['agreedAt'] as String?,
      );
}

/// GET/PUT /notifications/prefs/me (notification-svc NotificationPrefsView).
/// PUT은 전체 교체이므로 토글 시 [copyWith]로 나머지 필드를 유지한다.
class NotificationPrefs {
  const NotificationPrefs({
    required this.timezone,
    required this.preferredTimeSlot,
    required this.reminderEnabled,
    required this.weeklyReportEmailEnabled,
  });

  final String timezone;
  final String preferredTimeSlot;
  final bool reminderEnabled;
  final bool weeklyReportEmailEnabled;

  factory NotificationPrefs.fromJson(Map<String, dynamic> json) =>
      NotificationPrefs(
        timezone: json['timezone'] as String? ?? 'Asia/Seoul',
        preferredTimeSlot: json['preferredTimeSlot'] as String? ?? '09:00',
        reminderEnabled: json['reminderEnabled'] as bool? ?? true,
        weeklyReportEmailEnabled:
            json['weeklyReportEmailEnabled'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
    'timezone': timezone,
    'preferredTimeSlot': preferredTimeSlot,
    'reminderEnabled': reminderEnabled,
    'weeklyReportEmailEnabled': weeklyReportEmailEnabled,
  };

  NotificationPrefs copyWith({
    bool? reminderEnabled,
    bool? weeklyReportEmailEnabled,
  }) => NotificationPrefs(
    timezone: timezone,
    preferredTimeSlot: preferredTimeSlot,
    reminderEnabled: reminderEnabled ?? this.reminderEnabled,
    weeklyReportEmailEnabled:
        weeklyReportEmailEnabled ?? this.weeklyReportEmailEnabled,
  );
}
