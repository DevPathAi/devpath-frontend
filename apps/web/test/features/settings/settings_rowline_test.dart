import 'package:devpath_web/src/features/settings/application/settings_controller.dart';
import 'package:devpath_web/src/features/settings/data/settings_models.dart';
import 'package:devpath_web/src/features/settings/presentation/settings_page.dart';
import 'package:devpath_web/src/features/settings/state/settings_state.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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

Widget _app(
  WidgetTester tester, {
  Size size = const Size(1280, 2400),
  TextScaler? textScaler,
}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  if (textScaler != null) {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }
  return ProviderScope(
    overrides: [settingsControllerProvider.overrideWith(_ReadyController.new)],
    child: MaterialApp(theme: DpTheme.light(), home: const SettingsPage()),
  );
}

void main() {
  testWidgets('설정: 알림·동의 관리·계정 세 패널을 시안 순서로 그린다', (tester) async {
    await tester.pumpWidget(_app(tester));
    await tester.pumpAndSettle();

    final alarm = tester.getRect(find.text('알림'));
    final consent = tester.getRect(find.text('동의 관리'));
    final account = tester.getRect(find.text('계정'));
    expect(consent.top, greaterThan(alarm.top));
    expect(account.top, greaterThan(consent.top));
  });

  testWidgets('설정: 행을 DpRowLine 으로 그리고 ListTile 을 쓰지 않는다', (tester) async {
    await tester.pumpWidget(_app(tester));
    await tester.pumpAndSettle();

    expect(find.byType(DpRowLine), findsWidgets);
    expect(find.byType(SwitchListTile), findsNothing);
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('설정: 본문 폭이 readableMaxWidth(760) 를 넘지 않는다', (tester) async {
    await tester.pumpWidget(_app(tester));
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byType(DpRowLine).first).width,
      lessThanOrEqualTo(760),
    );
  });

  testWidgets('설정: 390px · 200% 배율에서 행이 깨지지 않는다', (tester) async {
    await tester.pumpWidget(
      _app(
        tester,
        size: const Size(390, 6000),
        textScaler: const TextScaler.linear(2),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(DpRowLine), findsWidgets);
  });
}
