import 'package:devpath_admin/src/features/support/application/support_controller.dart';
import 'package:devpath_admin/src/features/support/data/support_request.dart';
import 'package:devpath_admin/src/features/support/presentation/support_page.dart';
import 'package:devpath_admin/src/features/support/state/support_state.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:devpath_admin/src/features/shell/presentation/admin_shell.dart';
import 'package:flutter_test/flutter_test.dart';

/// build 를 고정해 목 API 호출 없이 렌더만 검증하는 가짜 컨트롤러
/// (reports_page_test.dart의 관용구 승계).
class _Fake extends SupportListController {
  _Fake(this.initial);
  final List<SupportRequestRow> initial;

  @override
  SupportListState build() => SupportListLoaded(initial);

  @override
  Future<void> load({String? status = 'OPEN', String? type}) async {
    state = SupportListLoaded(initial, status: status, type: type);
  }
}

void main() {
  testWidgets('unknown status keeps the raw wire beside an explicit label', (
    tester,
  ) async {
    final c = ProviderContainer(
      overrides: [
        supportListProvider.overrideWith(
          () => _Fake(const [
            SupportRequestRow(
              id: 1,
              type: 'ERROR',
              title: '새 상태',
              status: 'ESCALATED_BY_VENDOR',
              failureCount: 0,
            ),
          ]),
        ),
      ],
    );
    addTearDown(c.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(theme: DpTheme.light(), home: const SupportPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('알 수 없는 상태'), findsOneWidget);
    expect(find.text('(ESCALATED_BY_VENDOR)'), findsOneWidget);
  });

  testWidgets('DpPageHeader 제목은 "오류 신고·문의" + 상태 필터가 filters 슬롯에 렌더', (
    tester,
  ) async {
    final c = ProviderContainer(
      overrides: [supportListProvider.overrideWith(() => _Fake(const []))],
    );
    addTearDown(c.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(theme: DpTheme.light(), home: const SupportPage()),
      ),
    );
    await tester.pumpAndSettle();

    final header = tester.widget<DpPageHeader>(find.byType(DpPageHeader));
    expect(header.title, '오류 신고·문의');
    // 화면이 실제로 adminHeaderTitleFor를 호출한다는 것만 확인한다(경로 인자 오타 등).
    // 상수 값 변경 감지는 위 리터럴 단언의 몫이고, 화면이 같은 값의 리터럴로 퇴행하는
    // 방향은 admin_title_source_test의 소스 검사가 막는다.
    expect(header.title, adminHeaderTitleFor('/support'));
    expect(find.byKey(const ValueKey('page-header-filters')), findsOneWidget);
  });

  testWidgets('PUBLIC_HOME 상세에 회신 이메일과 개인정보 동의를 표시한다', (tester) async {
    final note = TextEditingController();
    addTearDown(note.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: DpTheme.light(),
        home: Scaffold(
          body: AdminSupportDetailProjection(
            detail: const SupportRequestDetail(
              id: 21,
              type: 'INQUIRY',
              title: '공개 문의',
              body: '답변을 부탁드립니다.',
              status: 'OPEN',
              failures: [],
              reporterId: null,
              source: 'PUBLIC_HOME',
              contactEmail: 'reader@example.com',
              privacyConsentAt: '2026-09-05T10:11:12Z',
            ),
            noteController: note,
          ),
        ),
      ),
    );

    expect(find.text('PUBLIC_HOME'), findsOneWidget);
    expect(find.text('reader@example.com'), findsOneWidget);
    expect(find.text('2026-09-05T10:11:12Z'), findsOneWidget);
    expect(find.text('접수자'), findsNothing);
  });
}
