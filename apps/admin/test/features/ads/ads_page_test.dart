import 'package:devpath_admin/src/features/ads/data/ad_row.dart';
import 'package:devpath_admin/src/features/ads/data/ad_slot_config_row.dart';
import 'package:devpath_admin/src/features/ads/data/ads_source.dart';
import 'package:devpath_admin/src/features/ads/presentation/ads_page.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:devpath_admin/src/features/shell/presentation/admin_shell.dart';
import 'package:flutter_test/flutter_test.dart';

AdRow _ad(int id, String title) => AdRow(
  id: id,
  title: title,
  imageUrl: null,
  linkUrl: 'https://e.com',
  slot: 'DASHBOARD_TOP',
  weight: 1,
  status: 'ACTIVE',
  startsAt: null,
  endsAt: null,
);

List<AdSlotConfigRow> _configs() => const [
  AdSlotConfigRow(slot: 'COMMUNITY_FEED', source: 'HOUSE', adsenseSlotId: null),
  AdSlotConfigRow(slot: 'CONTENT_PAGE', source: 'HOUSE', adsenseSlotId: null),
  AdSlotConfigRow(slot: 'DASHBOARD_TOP', source: 'HOUSE', adsenseSlotId: null),
];

void main() {
  testWidgets('renders ad rows and global switch', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adsListProvider.overrideWithValue(
            ({slot, status}) async => [_ad(1, '첫 배너')],
          ),
          adSettingsGetProvider.overrideWithValue(() async => true),
          adSlotConfigListProvider.overrideWithValue(() async => _configs()),
        ],
        child: MaterialApp(theme: DpTheme.light(), home: const AdminAdsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('첫 배너'), findsOneWidget);
    expect(find.byType(Switch), findsWidgets); // 전역 스위치 + 행 토글
  });

  testWidgets('tapping 광고 생성 opens form dialog', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adsListProvider.overrideWithValue(
            ({slot, status}) async => [_ad(1, '기존 배너')],
          ),
          adSettingsGetProvider.overrideWithValue(() async => false),
          adSlotConfigListProvider.overrideWithValue(() async => _configs()),
        ],
        child: MaterialApp(theme: DpTheme.light(), home: const AdminAdsPage()),
      ),
    );
    await tester.pumpAndSettle();

    // 목록이 비어있지 않아 DpEmpty가 없으므로 헤더의 생성 버튼만 존재.
    await tester.tap(find.widgetWithText(FilledButton, '광고 생성'));
    await tester.pumpAndSettle();
    expect(find.text('링크 URL'), findsOneWidget); // 폼 필드 라벨
  });

  testWidgets('행 MenuAnchor에 수정/통계/삭제가 있다', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adsListProvider.overrideWithValue(
            ({slot, status}) async => [_ad(1, '첫 배너')],
          ),
          adSettingsGetProvider.overrideWithValue(() async => true),
          adSlotConfigListProvider.overrideWithValue(() async => _configs()),
        ],
        child: MaterialApp(theme: DpTheme.light(), home: const AdminAdsPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(DpIcons.moreVert));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(MenuItemButton, '수정'), findsOneWidget);
    expect(find.widgetWithText(MenuItemButton, '통계'), findsOneWidget);
    expect(find.widgetWithText(MenuItemButton, '삭제'), findsOneWidget);
  });

  testWidgets('ads_page: 행 선택 시 벌크바 등장', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adsListProvider.overrideWithValue(
            ({slot, status}) async => [_ad(1, '첫 배너')],
          ),
          adSettingsGetProvider.overrideWithValue(() async => false),
          adSlotConfigListProvider.overrideWithValue(() async => _configs()),
        ],
        child: MaterialApp(theme: DpTheme.light(), home: const AdminAdsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ads-bulk-bar')), findsNothing);
    await tester.tap(find.byType(Checkbox).last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ads-bulk-bar')), findsOneWidget);
  });

  testWidgets('DpPageHeader 제목은 "광고 관리" + 슬롯 필터가 filters 슬롯에 렌더', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adsListProvider.overrideWithValue(({slot, status}) async => []),
          adSettingsGetProvider.overrideWithValue(() async => false),
          adSlotConfigListProvider.overrideWithValue(() async => _configs()),
        ],
        child: MaterialApp(theme: DpTheme.light(), home: const AdminAdsPage()),
      ),
    );
    await tester.pumpAndSettle();

    final header = tester.widget<DpPageHeader>(find.byType(DpPageHeader));
    expect(header.title, '광고 관리');
    // 화면이 실제로 adminHeaderTitleFor를 호출한다는 것만 확인한다(경로 인자 오타 등).
    // 상수 값 변경 감지는 위 리터럴 단언의 몫이고, 화면이 같은 값의 리터럴로 퇴행하는
    // 방향은 admin_title_source_test의 소스 검사가 막는다.
    expect(header.title, adminHeaderTitleFor('/ads'));
    expect(find.byKey(const ValueKey('page-header-filters')), findsOneWidget);
  });

  testWidgets('슬롯 설정 버튼이 다이얼로그를 열고 3행을 보여준다', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adsListProvider.overrideWithValue(
            ({slot, status}) async => [_ad(1, '첫 배너')],
          ),
          adSettingsGetProvider.overrideWithValue(() async => true),
          adSlotConfigListProvider.overrideWithValue(() async => _configs()),
        ],
        child: MaterialApp(theme: DpTheme.light(), home: const AdminAdsPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, '슬롯 설정'));
    await tester.pumpAndSettle();

    expect(find.text('DASHBOARD_TOP'), findsWidgets);
    expect(find.byType(DropdownButtonFormField<String>), findsNWidgets(3));
  });

  testWidgets('애드센스를 고르고 단위 ID를 비우면 경고가 뜬다', (tester) async {
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adsListProvider.overrideWithValue(
            ({slot, status}) async => [_ad(1, '첫 배너')],
          ),
          adSettingsGetProvider.overrideWithValue(() async => true),
          adSlotConfigListProvider.overrideWithValue(() async => _configs()),
        ],
        child: MaterialApp(theme: DpTheme.light(), home: const AdminAdsPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, '슬롯 설정'));
    await tester.pumpAndSettle();

    expect(find.text('단위 ID가 없으면 이 슬롯은 노출되지 않습니다'), findsNothing);

    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('애드센스').last);
    await tester.pumpAndSettle();

    expect(find.text('단위 ID가 없으면 이 슬롯은 노출되지 않습니다'), findsOneWidget);
  });
}
