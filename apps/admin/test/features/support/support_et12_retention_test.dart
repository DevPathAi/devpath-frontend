import 'package:devpath_admin/src/features/support/application/support_controller.dart';
import 'package:devpath_admin/src/features/support/data/support_request.dart';
import 'package:devpath_admin/src/features/support/data/support_source.dart';
import 'package:devpath_admin/src/features/support/presentation/support_page.dart';
import 'package:devpath_admin/src/features/support/state/support_state.dart';
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _row = SupportRequestRow(
  id: 7,
  type: 'INQUIRY',
  title: '질문',
  status: 'OPEN',
  failureCount: 0,
);

const _detail = SupportRequestDetail(
  id: 7,
  type: 'INQUIRY',
  title: '질문',
  body: '도움이 필요합니다.',
  status: 'OPEN',
  failures: [],
);

void main() {
  test(
    'status failure keeps loaded rows/filter and returns its message',
    () async {
      final container = ProviderContainer(
        overrides: [
          supportListFetchProvider.overrideWithValue(
            ({status, type, required limit}) async => const [_row],
          ),
          supportStatusUpdateProvider.overrideWithValue(
            (id, status, {adminNote}) async => throw const ApiException(
              code: ApiErrorCode.unknown,
              message: '저장 실패',
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(supportListProvider.notifier).load(status: 'OPEN');
      final before = container.read(supportListProvider);
      final error = await container
          .read(supportListProvider.notifier)
          .updateStatus(7, 'IN_PROGRESS', adminNote: '확인 중');

      expect(error, '저장 실패');
      expect(container.read(supportListProvider), same(before));
      expect(before, isA<SupportListLoaded>());
    },
  );

  test(
    'unknown support status is read-only and never reaches update provider',
    () async {
      var calls = 0;
      final container = ProviderContainer(
        overrides: [
          supportListFetchProvider.overrideWithValue(
            ({status, type, required limit}) async => const [
              SupportRequestRow(
                id: 11,
                type: 'INQUIRY',
                title: '외부 상태',
                status: 'VENDOR_ESCALATED',
                failureCount: 0,
              ),
            ],
          ),
          supportStatusUpdateProvider.overrideWithValue((
            id,
            status, {
            adminNote,
          }) async {
            calls++;
          }),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(supportListProvider.notifier)
          .load(status: 'VENDOR_ESCALATED');
      final before = container.read(supportListProvider);
      final error = await container
          .read(supportListProvider.notifier)
          .updateStatus(11, 'RESOLVED');

      expect(error, isNotNull);
      expect(calls, 0);
      expect(container.read(supportListProvider), same(before));
    },
  );

  testWidgets('dialog failure keeps note and stays open at 320/200%', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          supportListFetchProvider.overrideWithValue(
            ({status, type, required limit}) async => const [_row],
          ),
          supportDetailFetchProvider.overrideWithValue((id) async => _detail),
          supportStatusUpdateProvider.overrideWithValue(
            (id, status, {adminNote}) async => throw const ApiException(
              code: ApiErrorCode.unknown,
              message: '저장 실패',
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
          home: const SupportPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('질문'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('support-admin-note')),
      '계속 조사 중',
    );
    await tester.tap(find.text('처리 시작'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('저장 실패'), findsOneWidget);
    expect(find.text('계속 조사 중'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'detail fetch failure renders pending/error/retry without throwing',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            supportListFetchProvider.overrideWithValue(
              ({status, type, required limit}) async => const [_row],
            ),
            supportDetailFetchProvider.overrideWithValue(
              (id) async => throw const ApiException(
                code: ApiErrorCode.unknown,
                message: '상세 조회 실패',
              ),
            ),
          ],
          child: MaterialApp(theme: DpTheme.light(), home: const SupportPage()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('질문'));
      await tester.pump();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.pumpAndSettle();

      expect(find.text('상세 조회 실패'), findsOneWidget);
      expect(find.text('다시 시도'), findsOneWidget);
      expect(find.text('질문'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('unknown support detail is raw-only and has no mutations', (
    tester,
  ) async {
    const unknownRow = SupportRequestRow(
      id: 12,
      type: 'INQUIRY',
      title: '외부 상태 상세',
      status: 'VENDOR_ESCALATED',
      failureCount: 0,
    );
    const unknownDetail = SupportRequestDetail(
      id: 12,
      type: 'INQUIRY',
      title: '외부 상태 상세',
      body: '원문은 읽을 수 있습니다.',
      status: 'VENDOR_ESCALATED',
      failures: [],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          supportListFetchProvider.overrideWithValue(
            ({status, type, required limit}) async => const [unknownRow],
          ),
          supportDetailFetchProvider.overrideWithValue(
            (id) async => unknownDetail,
          ),
        ],
        child: MaterialApp(theme: DpTheme.light(), home: const SupportPage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('외부 상태 상세'));
    await tester.pumpAndSettle();

    expect(find.text('(VENDOR_ESCALATED)'), findsWidgets);
    expect(find.text('처리 시작'), findsNothing);
    expect(find.text('처리 완료'), findsNothing);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('support-admin-note')))
          .enabled,
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });
}
