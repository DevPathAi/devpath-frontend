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
  _ReadyController({this.agreedAt = '2026-07-01T09:00:00Z'});

  /// 서버가 보내는 원시 문자열. 해석 불가 값도 화면이 견뎌야 한다.
  final String? agreedAt;

  @override
  SettingsState build() => SettingsReady(
    consents: ConsentsView(
      consentStatus: 'DONE',
      items: [
        ConsentItemView(
          type: 'TERMS',
          agreed: true,
          version: 'v1',
          agreedAt: agreedAt,
        ),
        const ConsentItemView(type: 'MARKETING', agreed: true, version: 'v1'),
      ],
      birthYear: 2000,
    ),
    prefs: const NotificationPrefs(
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
  bool badDate = false,
}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  if (textScaler != null) {
    // 인자를 그대로 쓴다 — 상수 2 를 박아 두면 300% 를 검증했다고 믿게 된다.
    tester.platformDispatcher.textScaleFactorTestValue = textScaler.scale(1);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }
  return ProviderScope(
    overrides: [
      settingsControllerProvider.overrideWith(
        () => _ReadyController(
          agreedAt: badDate ? '언젠가' : '2026-07-01T09:00:00Z',
        ),
      ),
    ],
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

  testWidgets('설정: 동의 시각을 날짜로 읽히게 그린다 — 원시 ISO 문자열 금지', (tester) async {
    await tester.pumpWidget(_app(tester));
    await tester.pumpAndSettle();

    expect(find.text('2026.07.01 동의'), findsOneWidget);
    expect(find.textContaining('T09:00:00Z'), findsNothing);
  });

  testWidgets('설정: 날짜를 해석할 수 없으면 설명을 생략한다', (tester) async {
    await tester.pumpWidget(_app(tester, badDate: true));
    await tester.pumpAndSettle();

    expect(find.textContaining('언젠가'), findsNothing);
    expect(find.textContaining('동의'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
