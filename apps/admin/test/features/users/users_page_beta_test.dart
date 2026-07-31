import 'package:devpath_admin/src/features/users/application/users_controller.dart';
import 'package:devpath_admin/src/features/users/data/admin_user_row.dart';
import 'package:devpath_admin/src/features/users/data/users_source.dart';
import 'package:devpath_admin/src/features/users/presentation/users_page.dart';
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart' hide Page;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Spy: approve / preApprove 호출 여부를 기록하는 UsersController 대역
// ---------------------------------------------------------------------------
class _SpyController extends UsersController {
  final List<String> approvedIds = [];
  final List<String> preApprovedEmails = [];

  @override
  Future<void> approve(String userId) async {
    approvedIds.add(userId);
    // load()를 실제 호출하지 않으므로 state를 직접 갱신하지 않음
  }

  @override
  Future<void> preApprove(String email) async {
    preApprovedEmails.add(email);
  }
}

// ---------------------------------------------------------------------------
// 헬퍼: BETA_PENDING 행 포함 고정 데이터를 반환하는 컨테이너
// ---------------------------------------------------------------------------
ProviderContainer _makeContainer({UsersController? controller}) {
  return ProviderContainer(
    overrides: [
      adminUsersFetchProvider.overrideWithValue(
        ({String? cursor, String? status}) async => Page(
          data: [
            AdminUserRow(
              id: 'u-pending',
              nickname: '대기자',
              email: 'pending@example.com',
              role: UserRole.learner,
              status: 'BETA_PENDING',
            ),
            AdminUserRow(
              id: 'u-active',
              nickname: '활성유저',
              email: 'active@example.com',
              role: UserRole.learner,
              status: 'ACTIVE',
            ),
          ],
          limit: 20,
        ),
      ),
      if (controller != null) adminUsersProvider.overrideWith(() => controller),
    ],
  );
}

Widget _wrap(ProviderContainer container) => UncontrolledProviderScope(
  container: container,
  child: MaterialApp(theme: DpTheme.light(), home: const AdminUsersPage()),
);

void main() {
  // -------------------------------------------------------------------------
  // (a) 상태 필터에 BETA_PENDING 칩이 존재한다
  // -------------------------------------------------------------------------
  testWidgets('(a) 상태 필터에 BETA_PENDING ChoiceChip이 가장 먼저 렌더된다', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final c = _makeContainer();
    addTearDown(c.dispose);

    await tester.pumpWidget(_wrap(c));
    await tester.pumpAndSettle();

    // 칩이 존재해야 한다 (테이블 셀에도 BETA_PENDING이 나타날 수 있으므로 findsWidgets)
    expect(find.text('BETA_PENDING'), findsWidgets);

    // BETA_PENDING이 ACTIVE 칩보다 먼저 나타나야 한다
    // ChoiceChip 위젯 기준으로 위치 비교 (테이블 셀의 ACTIVE 텍스트와 혼동 방지)
    final chips = find.byType(ChoiceChip);
    final chipWidgets = tester.widgetList<ChoiceChip>(chips).toList();
    final chipLabels = chipWidgets.map((c) {
      final label = c.label;
      if (label is Text) return label.data ?? '';
      return '';
    }).toList();
    final betaIdx = chipLabels.indexOf('BETA_PENDING');
    final activeIdx = chipLabels.indexOf('ACTIVE');
    expect(
      betaIdx,
      greaterThanOrEqualTo(0),
      reason: 'BETA_PENDING chip not found',
    );
    expect(activeIdx, greaterThanOrEqualTo(0), reason: 'ACTIVE chip not found');
    expect(betaIdx, lessThan(activeIdx));
  });

  // -------------------------------------------------------------------------
  // (b) BETA_PENDING 행 선택 시 승인 버튼이 나타나고 탭하면 approve() 호출
  // -------------------------------------------------------------------------
  testWidgets('(b) BETA_PENDING 행 메뉴에 승인이 있고 탭하면 approve(id) 호출', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final spy = _SpyController();
    final c = _makeContainer(controller: spy);
    addTearDown(c.dispose);

    await tester.pumpWidget(_wrap(c));
    await tester.pumpAndSettle();

    // 첫 행(대기자, BETA_PENDING)의 MenuAnchor 열기
    await tester.tap(find.byIcon(DpIcons.moreVert).first);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(MenuItemButton, '승인'), findsOneWidget);
    expect(find.text('영구 밴'), findsNothing); // BETA_PENDING엔 제재 없음

    await tester.tap(find.widgetWithText(MenuItemButton, '승인'));
    await tester.pumpAndSettle();
    expect(spy.approvedIds, contains('u-pending'));
  });

  // -------------------------------------------------------------------------
  // (b-2) ACTIVE 행 선택 시 기존 제재 버튼이 표시된다 (기존 동작 보존)
  // -------------------------------------------------------------------------
  testWidgets('(b-2) ACTIVE 행 메뉴에 제재가 있다', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final c = _makeContainer();
    addTearDown(c.dispose);

    await tester.pumpWidget(_wrap(c));
    await tester.pumpAndSettle();

    // 둘째 행(활성유저, ACTIVE)의 MenuAnchor 열기
    await tester.tap(find.byIcon(DpIcons.moreVert).at(1));
    await tester.pumpAndSettle();

    expect(find.text('영구 밴'), findsOneWidget);
    expect(find.widgetWithText(MenuItemButton, '승인'), findsNothing);
  });

  // -------------------------------------------------------------------------
  // (c) 사전승인 이메일 필드 + 버튼이 존재하고 입력 후 탭하면 preApprove() 호출
  // -------------------------------------------------------------------------
  testWidgets('(c) 사전승인 이메일 필드와 허용리스트 추가 버튼이 있고, 입력 후 탭하면 preApprove() 호출', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final spy = _SpyController();
    final c = _makeContainer(controller: spy);
    addTearDown(c.dispose);

    await tester.pumpWidget(_wrap(c));
    await tester.pumpAndSettle();

    // 사전승인 버튼 존재
    expect(find.text('허용리스트 추가'), findsOneWidget);

    // 이메일 입력 필드에 입력
    await tester.enterText(find.byType(TextField).first, 'new@example.com');
    await tester.pumpAndSettle();

    // 버튼 탭
    await tester.tap(find.text('허용리스트 추가'));
    await tester.pumpAndSettle();

    expect(spy.preApprovedEmails, contains('new@example.com'));

    // 성공 SnackBar가 뜬다
    expect(find.byType(SnackBar), findsOneWidget);
  });
}
