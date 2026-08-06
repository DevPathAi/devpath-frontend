import 'package:devpath_admin/src/features/support/application/support_controller.dart';
import 'package:devpath_admin/src/features/support/data/support_request.dart';
import 'package:devpath_admin/src/features/support/presentation/support_page.dart';
import 'package:devpath_admin/src/features/support/state/support_state.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    expect(find.byKey(const ValueKey('page-header-filters')), findsOneWidget);
  });
}
