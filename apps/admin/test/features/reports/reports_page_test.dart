import 'package:devpath_admin/src/features/reports/application/reports_controller.dart';
import 'package:devpath_admin/src/features/reports/data/report.dart';
import 'package:devpath_admin/src/features/reports/presentation/reports_page.dart';
import 'package:devpath_admin/src/features/reports/state/reports_state.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

ProviderContainer _container(_Fake fake) {
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
}
