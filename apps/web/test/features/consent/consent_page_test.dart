import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:devpath_web/src/features/consent/application/consent_controller.dart';
import 'package:devpath_web/src/features/consent/presentation/consent_page.dart';
import 'package:devpath_web/src/features/consent/state/consent_state.dart';

MaterialApp _app() =>
    MaterialApp(theme: DpTheme.light(), home: const ConsentPage());

/// ConsentBlocked 상태로 고정하는 fake(차단 화면 렌더 검증).
class _BlockedController extends ConsentController {
  @override
  ConsentState build() => const ConsentBlocked();
}

void main() {
  void bigView(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('초기: 필수 미동의 → 제출 버튼 비활성', (tester) async {
    bigView(tester);
    await tester.pumpWidget(ProviderScope(child: _app()));

    expect(find.text('서비스 이용약관 동의'), findsOneWidget);
    expect(find.text('개인정보 수집·이용 동의'), findsOneWidget);

    final btn = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '동의하고 계속하기'),
    );
    expect(btn.onPressed, isNull); // 필수 미동의 → 비활성
  });

  testWidgets('필수 2종 체크 + 생년 입력 → 제출 버튼 활성', (tester) async {
    bigView(tester);
    await tester.pumpWidget(ProviderScope(child: _app()));

    await tester.tap(find.text('서비스 이용약관 동의'));
    await tester.tap(find.text('개인정보 수집·이용 동의'));
    await tester.enterText(find.byType(TextField), '2000');
    await tester.pump();

    final btn = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '동의하고 계속하기'),
    );
    expect(btn.onPressed, isNotNull); // 필수 완료 + 생년 → 활성
  });

  testWidgets('ConsentBlocked → 차단 안내 + 로그아웃 버튼', (tester) async {
    bigView(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          consentControllerProvider.overrideWith(_BlockedController.new),
        ],
        child: _app(),
      ),
    );

    expect(find.text('가입할 수 없어요'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, '로그아웃'), findsOneWidget);
  });
}
