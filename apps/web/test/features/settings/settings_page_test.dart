import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:devpath_web/src/features/settings/application/settings_controller.dart';
import 'package:devpath_web/src/features/settings/data/settings_models.dart';
import 'package:devpath_web/src/features/settings/presentation/settings_page.dart';
import 'package:devpath_web/src/features/settings/state/settings_state.dart';

/// SettingsReady 상태로 고정(load no-op)해 렌더만 검증.
class _ReadyController extends SettingsController {
  @override
  SettingsState build() => const SettingsReady(
    consents: ConsentsView(
      consentStatus: 'DONE',
      items: [
        ConsentItemView(type: 'TERMS', agreed: true, version: 'v1'),
        ConsentItemView(type: 'MARKETING', agreed: true, version: 'v1'),
      ],
      birthYear: 2000,
    ),
    prefs: NotificationPrefs(
      timezone: 'Asia/Seoul',
      preferredTimeSlot: '09:00',
      reminderEnabled: true,
      weeklyReportEmailEnabled: true,
    ),
  );

  @override
  Future<void> load() async {}
}

void main() {
  testWidgets('SettingsReady → 동의·알림·계정 섹션 렌더', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsControllerProvider.overrideWith(_ReadyController.new),
        ],
        child: MaterialApp(theme: DpTheme.light(), home: const SettingsPage()),
      ),
    );
    await tester.pump();

    // 알림 섹션
    expect(find.text('학습 리마인더'), findsOneWidget);
    expect(find.text('주간 리포트 이메일'), findsOneWidget);
    // 계정 섹션
    expect(find.text('로그아웃'), findsOneWidget);
    expect(find.text('계정 삭제'), findsOneWidget);
    // 선택 동의 표시(철회 가능)
    expect(find.text('마케팅 정보 수신'), findsOneWidget);
  });
}
