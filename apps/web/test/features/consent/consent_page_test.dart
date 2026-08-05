import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:devpath_web/src/features/consent/application/consent_controller.dart';
import 'package:devpath_web/src/features/consent/application/consent_source.dart';
import 'package:devpath_web/src/features/consent/presentation/consent_page.dart';
import 'package:devpath_web/src/features/consent/state/consent_state.dart';

MaterialApp _app() =>
    MaterialApp(theme: DpTheme.light(), home: const ConsentPage());

/// ConsentBlocked 상태로 고정하는 fake(차단 화면 렌더 검증).
class _BlockedController extends ConsentController {
  @override
  ConsentState build() => const ConsentBlocked();
}

/// submit 호출을 기록하는 fake — 실제 네트워크 없이 검증 게이트 통과 여부만 본다.
class _RecordingController extends ConsentController {
  int submits = 0;
  int? lastBirthYear;

  @override
  Future<void> submit({
    required List<ConsentSubmitItem> items,
    required int birthYear,
  }) async {
    submits++;
    lastBirthYear = birthYear;
  }
}

void main() {
  void bigView(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('AppBar 없이 헤더로 대체', (tester) async {
    bigView(tester);
    await tester.pumpWidget(ProviderScope(child: _app()));

    expect(find.byType(AppBar), findsNothing);
    final header = tester.widget<DpPageHeader>(find.byType(DpPageHeader));
    expect(header.title, '가입 전 동의');
    expect(header.description, '서비스 이용에 필요한 항목입니다');
    // F4 회귀 가드: brandRow(context) 호출을 지워도 위 단언들은 깨지지
    // 않는다 — 셸 밖 화면의 유일한 제품 정체성 표시이므로 존재를 직접
    // 단언한다(brand_row.dart의 key로, find.text보다 견고하다).
    expect(find.byKey(const ValueKey('brand-row')), findsOneWidget);
  });

  testWidgets('제출 버튼은 항상 활성 — 조용한 비활성 금지', (tester) async {
    // 회귀 고정: 미충족 상태에서 버튼을 비활성으로 두면 사용자가 "무엇이
    // 부족한지" 알 수 없이 갇힌다(2026-07-27 운영에서 출생연도 미등록 상태로
    // 진행 불가). 버튼은 활성 유지, 탭 시 검증 메시지로 안내한다.
    bigView(tester);
    await tester.pumpWidget(ProviderScope(child: _app()));

    expect(find.text('서비스 이용약관 동의'), findsOneWidget);
    expect(find.text('개인정보 수집·이용 동의'), findsOneWidget);

    final btn = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '동의하고 계속하기'),
    );
    expect(btn.onPressed, isNotNull);
  });

  testWidgets('필수 체크 + 생년 미입력 → 탭 시 생년 에러 노출·submit 미호출', (tester) async {
    bigView(tester);
    final recorder = _RecordingController();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [consentControllerProvider.overrideWith(() => recorder)],
        child: _app(),
      ),
    );

    await tester.tap(find.text('서비스 이용약관 동의'));
    await tester.tap(find.text('개인정보 수집·이용 동의'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '동의하고 계속하기'));
    await tester.pump();

    expect(find.textContaining('출생 연도'), findsWidgets);
    expect(find.text('출생 연도 4자리를 숫자로 입력해 주세요 (예: 1995)'), findsOneWidget);
    expect(recorder.submits, 0, reason: '검증 실패 시 submit이 호출되면 안 된다');
  });

  testWidgets('필수 미체크 → 탭 시 필수 안내 노출·submit 미호출', (tester) async {
    bigView(tester);
    final recorder = _RecordingController();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [consentControllerProvider.overrideWith(() => recorder)],
        child: _app(),
      ),
    );

    await tester.enterText(find.byType(TextField), '1995');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '동의하고 계속하기'));
    await tester.pump();

    expect(find.text('필수 항목(이용약관·개인정보)에 모두 동의해 주세요.'), findsOneWidget);
    expect(recorder.submits, 0);
  });

  testWidgets('필수 체크 + 생년 입력 → 탭 시 submit 1회 호출', (tester) async {
    bigView(tester);
    final recorder = _RecordingController();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [consentControllerProvider.overrideWith(() => recorder)],
        child: _app(),
      ),
    );

    await tester.tap(find.text('서비스 이용약관 동의'));
    await tester.tap(find.text('개인정보 수집·이용 동의'));
    await tester.enterText(find.byType(TextField), '2000');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '동의하고 계속하기'));
    await tester.pump();

    expect(recorder.submits, 1);
    expect(recorder.lastBirthYear, 2000);
  });

  testWidgets('전각 숫자(１９９５)도 정규화되어 제출된다 — IME 전각 입력 내성', (tester) async {
    bigView(tester);
    final recorder = _RecordingController();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [consentControllerProvider.overrideWith(() => recorder)],
        child: _app(),
      ),
    );

    await tester.tap(find.text('서비스 이용약관 동의'));
    await tester.tap(find.text('개인정보 수집·이용 동의'));
    await tester.enterText(find.byType(TextField), '１９９５');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '동의하고 계속하기'));
    await tester.pump();

    expect(recorder.submits, 1, reason: '전각 숫자는 반각으로 정규화되어 파싱돼야 한다');
    expect(recorder.lastBirthYear, 1995);
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
