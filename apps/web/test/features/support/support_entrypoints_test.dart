import 'package:dp_design/dp_design.dart';
import 'package:devpath_web/src/features/shell/presentation/app_shell.dart';
import 'package:devpath_web/src/features/support/presentation/supportable_error.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('SupportableError 는 문의하기 버튼을 항상 노출한다', (tester) async {
    // DpError 가 context.dpColors 를 쓰므로 DpTheme 주입이 필요하다.
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: DpTheme.light(),
          home: const Scaffold(body: SupportableError(message: '문제가 생겼어요')),
        ),
      ),
    );

    expect(find.text('문의하기'), findsOneWidget);
  });

  testWidgets('앱셸 trailing 에 명령 팔레트와 제보 버튼이 함께 있다', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: DpTheme.light(),
          home: const AppShellView(
            location: '/dashboard',
            child: SizedBox.shrink(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 기존 명령 팔레트 진입점이 살아 있다(회귀 방지). Task 6에서 DpChromeBar로
    // 배선을 옮긴 뒤로는 비compact 폭에서 검색 진입점이 툴팁 버튼이 아니라
    // DpChromeBar의 내장 검색 상자(key: chrome-search)로 렌더된다.
    expect(find.byKey(const ValueKey('chrome-search')), findsOneWidget);
    // 새 제보 버튼이 추가됐다.
    expect(find.byTooltip('오류 신고·문의'), findsOneWidget);
  });
}
