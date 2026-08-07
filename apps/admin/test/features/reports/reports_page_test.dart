import 'package:devpath_admin/src/features/reports/application/reports_controller.dart';
import 'package:devpath_admin/src/features/reports/data/report.dart';
import 'package:devpath_admin/src/features/reports/presentation/reports_page.dart';
import 'package:devpath_admin/src/features/reports/state/reports_state.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:devpath_admin/src/features/shell/presentation/admin_shell.dart';
import 'package:flutter_test/flutter_test.dart';

AdminReport _r({
  int id = 1,
  String targetType = 'POST',
  String? targetTitle = '스팸 글',
  String category = 'AD',
  String? reason = '광고글입니다',
  int reportCount = 1,
  String status = 'OPEN',
  String? targetPath = '/community/post/10',
}) => AdminReport(
  id: id,
  targetType: targetType,
  targetId: 10,
  targetTitle: targetTitle,
  targetExcerpt: targetTitle == null ? null : '본문 일부…',
  targetPath: targetPath,
  category: category,
  reason: reason,
  reportCount: reportCount,
  status: status,
  createdAt: '2026-08-02T09:00:00Z',
);

/// build 를 고정하고 resolve 호출을 캡처하는 가짜 컨트롤러(기존 admin 테스트 관용구 승계).
class _Fake extends ReportsController {
  _Fake(this.initial);
  final List<AdminReport> initial;
  final calls = <({int id, String action})>[];

  @override
  ReportsState build() => ReportsLoaded(initial);

  @override
  Future<void> resolve(int id, String action) async {
    calls.add((id: id, action: action));
  }

  @override
  Future<void> load({String? status = 'OPEN'}) async {
    state = ReportsLoaded(initial, status: status);
  }
}

Future<void> _pump(WidgetTester tester, ProviderContainer c) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: MaterialApp(theme: DpTheme.light(), home: const ReportsPage()),
    ),
  );
  await tester.pumpAndSettle();
}

/// 로딩·실패 상태를 고정하는 가짜도 받을 수 있도록 상위 타입으로 받는다.
ProviderContainer _container(ReportsController fake) {
  final c = ProviderContainer(
    overrides: [reportsProvider.overrideWith(() => fake)],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  testWidgets('대상 제목·카테고리 라벨·신고 수를 렌더한다', (tester) async {
    final fake = _Fake([_r(category: 'AD', reportCount: 3)]);
    await _pump(tester, _container(fake));

    expect(find.text('스팸 글'), findsOneWidget);
    expect(find.text('광고'), findsWidgets, reason: 'AD 는 한글 라벨로 보여야 한다');
    expect(
      find.textContaining('3'),
      findsWidgets,
      reason: '신고 수가 보여야 심각도를 가늠할 수 있다',
    );
  });

  testWidgets('기각을 누르면 REJECT 로 호출한다', (tester) async {
    final fake = _Fake([_r(id: 7)]);
    await _pump(tester, _container(fake));

    await tester.tap(find.text('기각'));
    await tester.pumpAndSettle();

    expect(fake.calls, [(id: 7, action: 'REJECT')]);
  });

  testWidgets('처리완료를 누르면 RESOLVE 로 호출한다', (tester) async {
    final fake = _Fake([_r(id: 9)]);
    await _pump(tester, _container(fake));

    await tester.tap(find.text('처리완료'));
    await tester.pumpAndSettle();

    expect(fake.calls, [(id: 9, action: 'RESOLVE')]);
  });

  testWidgets('대상이 삭제된 신고는 "삭제된 콘텐츠"로 표시한다', (tester) async {
    final fake = _Fake([_r(targetTitle: null, targetPath: null)]);
    await _pump(tester, _container(fake));

    expect(find.textContaining('삭제된 콘텐츠'), findsOneWidget);
  });

  testWidgets('빈 목록이면 안내를 보여준다', (tester) async {
    await _pump(tester, _container(_Fake([])));

    expect(find.byType(DpEmpty), findsOneWidget);
  });

  testWidgets('status 필터를 바꾸면 그 값으로 재조회한다', (tester) async {
    final fake = _Fake([_r()]);
    final c = _container(fake);
    await _pump(tester, c);

    await tester.tap(find.text('기각됨'));
    await tester.pumpAndSettle();

    final s = c.read(reportsProvider);
    expect(s, isA<ReportsLoaded>());
    expect((s as ReportsLoaded).status, 'REJECTED');
  });

  testWidgets('DpPageHeader 제목은 "신고 처리" + 상태 필터가 filters 슬롯에 렌더', (
    tester,
  ) async {
    await _pump(tester, _container(_Fake([_r()])));

    final header = tester.widget<DpPageHeader>(find.byType(DpPageHeader));
    expect(header.title, '신고 처리');
    // 화면이 실제로 adminHeaderTitleFor를 호출한다는 것만 확인한다(경로 인자 오타 등).
    // 상수 값 변경 감지는 위 리터럴 단언의 몫이고, 화면이 같은 값의 리터럴로 퇴행하는
    // 방향은 admin_title_source_test의 소스 검사가 막는다.
    expect(header.title, adminHeaderTitleFor('/reports'));
    expect(find.byKey(const ValueKey('page-header-filters')), findsOneWidget);
  });

  // 아래 두 건은 sliver 전환(Task 12)이 만든 로딩·실패 분기를 잠근다. 빈 목록
  // 분기는 위 '빈 목록이면 안내를 보여준다'가 이미 커버한다. 전환 전에는
  // Expanded(child: ...)라 레이아웃이 자명했지만 지금은 SliverFillRemaining이라
  // 헤더와 같은 스크롤 표면 위에서 렌더된다 — 비-sliver를 넣으면 예외가 난다.
  testWidgets('로딩 중에도 헤더와 로딩 표시가 함께 렌더된다', (tester) async {
    // _pump 헬퍼는 pumpAndSettle을 쓰는데 이 케이스는 정착하지 않는다
    // (실측: pumpAndSettle timed out). 원인은 DpLoading 자체가 아니라
    // **로딩 상태를 영구 고정한 가짜 컨트롤러 + 그 안의 indeterminate
    // CircularProgressIndicator(repeat)** 조합이다 — 같은 파일의 다른
    // pumpAndSettle 테스트들이 멀쩡한 이유는 로딩이 일시적이라 인디케이터가
    // 트리에서 사라지기 때문이다. 그래서 이 케이스만 pump 한 번으로 렌더한다.
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: _container(_LoadingReports()),
        child: MaterialApp(theme: DpTheme.light(), home: const ReportsPage()),
      ),
    );
    await tester.pump();

    expect(
      tester.widget<DpPageHeader>(find.byType(DpPageHeader)).title,
      '신고 처리',
    );
    expect(find.byType(DpLoading), findsOneWidget);
  });

  testWidgets('조회 실패 시 헤더와 에러 안내가 함께 렌더된다', (tester) async {
    await _pump(tester, _container(_FailedReports()));

    expect(
      tester.widget<DpPageHeader>(find.byType(DpPageHeader)).title,
      '신고 처리',
    );
    expect(find.textContaining('신고를 불러오지 못했어요'), findsWidgets);
  });
}

class _LoadingReports extends ReportsController {
  @override
  ReportsState build() => const ReportsLoading();

  @override
  Future<void> load({String? status = 'OPEN'}) async {}
}

class _FailedReports extends ReportsController {
  @override
  ReportsState build() => const ReportsFailed('신고를 불러오지 못했어요');

  @override
  Future<void> load({String? status = 'OPEN'}) async {}
}
