import 'package:devpath_admin/src/features/ads/application/ads_controller.dart';
import 'package:devpath_admin/src/features/ads/data/ad_row.dart';
import 'package:devpath_admin/src/features/ads/data/ads_source.dart';
import 'package:devpath_admin/src/features/ads/presentation/ads_page.dart';
import 'package:devpath_admin/src/features/ads/state/ads_state.dart';
import 'package:devpath_admin/src/widgets/admin_status_widgets.dart';
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

AdRow _ad() => const AdRow(
  id: 1,
  title: '첫 배너',
  imageUrl: null,
  linkUrl: 'https://example.com',
  slot: 'DASHBOARD_TOP',
  weight: 1,
  status: 'ACTIVE',
  startsAt: null,
  endsAt: null,
);

void main() {
  testWidgets('status is visible, filter keeps raw wire, switch is labelled', (
    tester,
  ) async {
    String? sentStatus;
    tester.view.physicalSize = const Size(1240, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adsListProvider.overrideWithValue(({slot, status}) async {
            sentStatus = status;
            return [_ad()];
          }),
          adSettingsGetProvider.overrideWithValue(() async => true),
          adSlotConfigListProvider.overrideWithValue(() async => []),
        ],
        child: MaterialApp(theme: DpTheme.light(), home: const AdminAdsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AdminStatusFilter), findsOneWidget);
    expect(find.text('노출 중'), findsOneWidget);
    expect(find.text('(ACTIVE)'), findsOneWidget);
    expect(find.bySemanticsLabel('첫 배너 광고 상태: 노출 중 (ACTIVE)'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(AdminStatusFilter),
        matching: find.byType(DropdownButton<String>),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('일시 중지 (PAUSED)').last);
    await tester.pumpAndSettle();
    expect(sentStatus, 'PAUSED');
  });

  testWidgets('bulk delete asks impact and failure preserves selection', (
    tester,
  ) async {
    late ProviderContainer container;
    container = ProviderContainer(
      overrides: [
        adsListProvider.overrideWithValue(({slot, status}) async => [_ad()]),
        adSettingsGetProvider.overrideWithValue(() async => true),
        adSlotConfigListProvider.overrideWithValue(() async => []),
        adBulkDeleteProvider.overrideWithValue(
          (ids) async => throw const ApiException(
            code: ApiErrorCode.unknown,
            message: '삭제 실패',
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: DpTheme.light(), home: const AdminAdsPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Checkbox).last);
    await tester.pumpAndSettle();
    expect(container.read(adsProvider).selectedIds, {1});

    await tester.tap(find.text('삭제').first);
    await tester.pumpAndSettle();
    expect(find.text('선택한 광고 1개 삭제'), findsOneWidget);
    expect(find.textContaining('운영 노출에서 즉시 제거'), findsOneWidget);

    await tester.tap(find.text('1개 삭제'));
    await tester.pumpAndSettle();
    expect(find.text('삭제 실패'), findsOneWidget);
    expect(container.read(adsProvider).selectedIds, {1});
    expect(container.read(adsProvider).phase, AdsPhase.loaded);
  });

  testWidgets('create failure keeps the ad form and entered values', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adsListProvider.overrideWithValue(({slot, status}) async => [_ad()]),
          adSettingsGetProvider.overrideWithValue(() async => true),
          adSlotConfigListProvider.overrideWithValue(() async => []),
          adCreateProvider.overrideWithValue(
            (draft) async => throw const ApiException(
              code: ApiErrorCode.unknown,
              message: '광고 저장 실패',
            ),
          ),
        ],
        child: MaterialApp(
          theme: DpTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: const AdminAdsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, '광고 생성'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '보존할 광고 제목');
    await tester.enterText(
      find.byType(TextField).at(1),
      'https://example.com/ad',
    );
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('광고 저장 실패'), findsOneWidget);
    expect(find.text('보존할 광고 제목'), findsOneWidget);
    expect(find.text('https://example.com/ad'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
