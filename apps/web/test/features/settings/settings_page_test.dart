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

    expect(find.byType(AppBar), findsNothing);
    final header = tester.widget<DpPageHeader>(find.byType(DpPageHeader));
    expect(header.title, '설정');
    expect(header.description, '알림·동의·계정을 관리합니다');

    // 알림 섹션
    expect(find.text('학습 리마인더'), findsOneWidget);
    expect(find.text('주간 리포트 이메일'), findsOneWidget);
    // 계정 섹션
    // 시안 `.rowline` 은 좌측 라벨과 우측 컨트롤을 둘 다 둔다 — 같은 문구가
    // 행 이름과 버튼에 한 번씩 나오므로 버튼을 특정해 단언한다.
    expect(find.widgetWithText(OutlinedButton, '로그아웃'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, '계정 삭제'), findsOneWidget);
    expect(find.text('로그아웃'), findsNWidgets(2));
    expect(find.text('계정 삭제'), findsNWidgets(2));
    // 선택 동의 표시(철회 가능)
    expect(find.text('마케팅 정보 수신'), findsOneWidget);
  });

  // axe `aria-toggle-field-name`(serious) — 스위치에 접근 가능한 이름이 없으면
  // 스크린리더가 "켜짐"만 읽고 무엇이 켜졌는지 말하지 못한다. 시안도 설정 화면의
  // 각 입력에 `aria-label` 을 준다. S3-P5 의 browser-ux 라우트 확장이 /settings 를
  // 처음 재면서 5개 노드가 전부 걸렸다(로컬 핀 컨테이너 실측).
  testWidgets('설정의 모든 스위치가 자기 행 이름을 시맨틱 라벨로 갖는다', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    // addTearDown 은 프레임워크의 종료 검증보다 늦게 돌아
    // "A SemanticsHandle was active at the end of the test" 로 죽는다(실측).
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsControllerProvider.overrideWith(_ReadyController.new),
        ],
        child: MaterialApp(theme: DpTheme.light(), home: const SettingsPage()),
      ),
    );
    await tester.pumpAndSettle();

    final switches = find.byType(Switch);
    expect(switches, findsWidgets);
    for (var i = 0; i < tester.widgetList(switches).length; i++) {
      final label = tester.getSemantics(switches.at(i)).label;
      expect(
        label,
        isNotEmpty,
        reason: '스위치 $i 에 접근 가능한 이름이 없다(axe aria-toggle-field-name)',
      );
    }
    handle.dispose();
  });
}
