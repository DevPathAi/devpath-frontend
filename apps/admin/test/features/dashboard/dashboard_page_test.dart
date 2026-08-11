import 'package:devpath_admin/src/features/dashboard/application/dashboard_controller.dart';
import 'package:devpath_admin/src/features/dashboard/presentation/dashboard_page.dart';
import 'package:devpath_admin/src/features/dashboard/state/dashboard_state.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:devpath_admin/src/features/shell/presentation/admin_shell.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('KPI 카드(DAU·신규·신고) 렌더', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: DpTheme.light(),
          home: const AdminDashboardPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('1280'), findsWidgets); // DAU
    expect(find.textContaining('신고'), findsWidgets);
  });

  testWidgets('DpPageHeader 제목은 "운영 대시보드"', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: DpTheme.light(),
          home: const AdminDashboardPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final header = tester.widget<DpPageHeader>(find.byType(DpPageHeader));
    expect(header.title, '운영 대시보드');
    // 화면이 실제로 adminHeaderTitleFor를 호출한다는 것만 확인한다(경로 인자 오타 등).
    // 상수 값 변경 감지는 위 리터럴 단언의 몫이고, 화면이 같은 값의 리터럴로 퇴행하는
    // 방향은 admin_title_source_test의 소스 검사가 막는다.
    expect(header.title, adminHeaderTitleFor('/dashboard'));
  });

  testWidgets('로딩 중에도 헤더와 로딩 표시가 함께 렌더된다', (tester) async {
    final c = ProviderContainer(
      overrides: [adminDashProvider.overrideWith(_LoadingDashController.new)],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          theme: DpTheme.light(),
          home: const AdminDashboardPage(),
        ),
      ),
    );
    await tester.pump();

    expect(
      tester.widget<DpPageHeader>(find.byType(DpPageHeader)).title,
      '운영 대시보드',
    );
    expect(find.byType(DpLoading), findsOneWidget);
  });

  testWidgets('조회 실패 시 헤더와 에러 안내가 함께 렌더된다', (tester) async {
    final c = ProviderContainer(
      overrides: [adminDashProvider.overrideWith(_FailedDashController.new)],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          theme: DpTheme.light(),
          home: const AdminDashboardPage(),
        ),
      ),
    );
    await tester.pump();

    expect(
      tester.widget<DpPageHeader>(find.byType(DpPageHeader)).title,
      '운영 대시보드',
    );
    expect(find.textContaining('지표를 불러오지 못했어요'), findsWidgets);
  });
}

// 아래 두 건은 sliver 전환(Task 12)이 만든 로딩·실패 분기를 잠근다. 전환 전에는
// Expanded(child: ...)라 레이아웃이 자명했지만 지금은 SliverFillRemaining이라
// 헤더와 같은 스크롤 표면 위에서 렌더된다 — 비-sliver를 넣으면 RenderViewport가
// RenderSliver를 기대하며 예외를 던지고, 이 테스트가 그것을 적발한다.
class _LoadingDashController extends AdminDashController {
  @override
  AdminDashState build() => const AdminDashLoading();

  @override
  Future<void> load() async {}
}

class _FailedDashController extends AdminDashController {
  @override
  AdminDashState build() => const AdminDashFailed('지표를 불러오지 못했어요');

  @override
  Future<void> load() async {}
}
