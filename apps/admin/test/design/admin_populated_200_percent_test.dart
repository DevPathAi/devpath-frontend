import 'package:devpath_admin/src/features/ads/data/ad_row.dart';
import 'package:devpath_admin/src/features/ads/data/ad_stats_row.dart';
import 'package:devpath_admin/src/features/ads/data/ads_source.dart';
import 'package:devpath_admin/src/features/ads/presentation/ads_page.dart';
import 'package:devpath_admin/src/features/reports/data/report.dart';
import 'package:devpath_admin/src/features/reports/data/reports_source.dart';
import 'package:devpath_admin/src/features/reports/presentation/reports_page.dart';
import 'package:devpath_admin/src/features/support/data/support_request.dart';
import 'package:devpath_admin/src/features/support/data/support_source.dart';
import 'package:devpath_admin/src/features/support/presentation/support_page.dart';
import 'package:devpath_admin/src/features/users/data/admin_user_row.dart';
import 'package:devpath_admin/src/features/users/data/users_source.dart';
import 'package:devpath_admin/src/features/users/presentation/users_page.dart';
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart' hide Page;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _unknownWire = 'VENDOR_ESCALATED_WITH_EXTERNAL_REVIEW_PHASE_1234567';
const _longKorean = '운영자가 실제로 확인해야 하는 매우 긴 한국어 제목과 설명이 여러 줄로 이어집니다';

Future<void> _pump(WidgetTester tester, Widget home, dynamic overrides) async {
  tester.view.physicalSize = const Size(320, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: DpTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(2)),
          child: child!,
        ),
        home: home,
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets(
    'populated users table, unknown wire and bulk dialog fit 320/200%',
    (tester) async {
      await _pump(tester, const AdminUsersPage(), [
        adminUsersFetchProvider.overrideWithValue(
          ({cursor, status}) async => const Page(
            data: [
              AdminUserRow(
                id: '1',
                nickname: _longKorean,
                email: 'very-long-operator-pending-account@example.com',
                role: UserRole.learner,
                status: 'BETA_PENDING',
              ),
              AdminUserRow(
                id: '2',
                nickname: '외부 상태 사용자',
                email: 'external-state@example.com',
                role: UserRole.learner,
                status: _unknownWire,
              ),
            ],
            limit: 20,
          ),
        ),
      ]);

      expect(find.text('($_unknownWire)'), findsOneWidget);
      final selectable = tester
          .widgetList<Checkbox>(find.byType(Checkbox))
          .firstWhere((checkbox) => checkbox.onChanged != null);
      selectable.onChanged!(true);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('users-bulk-bar')), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, '승인'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('populated report cards and typed decision dialog fit 320/200%', (
    tester,
  ) async {
    await _pump(tester, const ReportsPage(), [
      reportsListFetchProvider.overrideWithValue(
        ({status, required page, required size}) async => const [
          AdminReport(
            id: 47,
            targetType: 'POST',
            targetId: 1,
            targetTitle: _longKorean,
            targetExcerpt: _longKorean,
            targetPath:
                '/community/post/very-long-47-character-diagnostic-path',
            category: 'SPAM',
            reason: _longKorean,
            reportCount: 12,
            status: 'OPEN',
            createdAt: null,
          ),
          AdminReport(
            id: 48,
            targetType: 'COMMENT',
            targetId: 2,
            targetTitle: '외부 상태 신고',
            targetExcerpt: '원문 보존',
            targetPath: '/community/post/2',
            category: 'ABUSE',
            reason: null,
            reportCount: 1,
            status: _unknownWire,
            createdAt: null,
          ),
        ],
      ),
    ]);

    expect(find.text('($_unknownWire)'), findsOneWidget);
    await tester.tap(find.text('기각'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('admin-danger-confirmation-input')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('populated support table and long detail dialog fit 320/200%', (
    tester,
  ) async {
    const row = SupportRequestRow(
      id: 77,
      type: 'ERROR',
      title: _longKorean,
      status: _unknownWire,
      failureCount: 4,
      pagePath: '/diagnostics/path/with/forty-seven-character-segment',
    );
    await _pump(tester, const SupportPage(), [
      supportListFetchProvider.overrideWithValue(
        ({status, type, required limit}) async => const [row],
      ),
      supportDetailFetchProvider.overrideWithValue(
        (id) async => const SupportRequestDetail(
          id: 77,
          type: 'ERROR',
          title: _longKorean,
          body: '$_longKorean $_longKorean',
          status: _unknownWire,
          failures: [
            SupportFailure(
              seq: 1,
              method: 'POST',
              path: '/api/diagnostics/very-long-request-path-for-operator',
              occurredAt: '2026-08-16T12:34:56Z',
              statusCode: 503,
              errorCode: _unknownWire,
              traceId: _unknownWire,
              message: _longKorean,
            ),
          ],
          traceId: _unknownWire,
        ),
      ),
    ]);

    expect(find.text('($_unknownWire)'), findsOneWidget);
    await tester.tap(find.text(_longKorean).first);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text(_unknownWire), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('populated ads table, bulk and stats dialog fit 320/200%', (
    tester,
  ) async {
    await _pump(tester, const AdminAdsPage(), [
      adsListProvider.overrideWithValue(
        ({slot, status}) async => const [
          AdRow(
            id: 1,
            title: _longKorean,
            imageUrl: null,
            linkUrl: 'https://example.com/a/very-long-campaign-link',
            slot: 'DASHBOARD_TOP',
            weight: 10,
            status: 'ACTIVE',
            startsAt: null,
            endsAt: null,
          ),
          AdRow(
            id: 2,
            title: '외부 상태 광고',
            imageUrl: null,
            linkUrl: 'https://example.com/unknown',
            slot: 'CONTENT_PAGE',
            weight: 1,
            status: _unknownWire,
            startsAt: null,
            endsAt: null,
          ),
        ],
      ),
      adSettingsGetProvider.overrideWithValue(() async => true),
      adSlotConfigListProvider.overrideWithValue(() async => []),
      adStatsProvider.overrideWithValue(
        (id, from, to) async => [
          AdStatsRow(
            date: DateTime(2026, 8, 16),
            impressions: 123456,
            clicks: 789,
          ),
        ],
      ),
    ]);

    expect(find.text('($_unknownWire)'), findsOneWidget);
    final selectable = tester
        .widgetList<Checkbox>(find.byType(Checkbox))
        .firstWhere((checkbox) => checkbox.onChanged != null);
    selectable.onChanged!(true);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ads-bulk-bar')), findsOneWidget);

    final menu = find.byIcon(DpIcons.moreVert);
    await tester.ensureVisible(menu);
    await tester.tap(menu);
    await tester.pumpAndSettle();
    await tester.tap(find.text('통계'));
    await tester.pumpAndSettle();
    expect(find.textContaining('통계 ·'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
