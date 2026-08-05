import 'package:devpath_web/src/features/mypage/application/mypage_controller.dart';
import 'package:devpath_web/src/features/mypage/presentation/mypage_page.dart';
import 'package:devpath_web/src/features/mypage/state/mypage_state.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// load()를 no-op으로 고정해 실제 네트워크 호출(및 dio 내부 pending Timer)을 피한다.
/// mypage_page_test.dart의 `_FixedController` 패턴 승계 — 헤더 배선만 검증하는
/// 이 테스트에는 MyPageLoaded까지 갈 필요가 없다(본문 로직은 이 Task 범위 밖).
class _FixedController extends MyPageController {
  @override
  MyPageState build() => const MyPageLoading();

  @override
  Future<void> load() async {}
}

void main() {
  testWidgets('마이페이지 헤더에 설정 버튼이 없다(계정 메뉴로 일원화)', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          myPageControllerProvider.overrideWith(_FixedController.new),
        ],
        child: MaterialApp(theme: DpTheme.light(), home: const MyPagePage()),
      ),
    );
    await tester.pump();
    expect(find.byType(AppBar), findsNothing);
    final header = tester.widget<DpPageHeader>(find.byType(DpPageHeader));
    expect(header.title, '마이페이지');
    expect(header.actions, isEmpty);
    expect(find.byIcon(Icons.settings_outlined), findsNothing);
  });
}
