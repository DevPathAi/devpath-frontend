import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:devpath_web/src/features/common/application/external_link_opener.dart';
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

/// 어떤 주소를 열었는지 기록하는 fake.
class _RecordingOpener implements ExternalLinkOpener {
  final List<String> opened = [];

  @override
  void open(String url) => opened.add(url);
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

  // 동의를 받으면서 방침 전문을 보여주지 않고 있었다. 한 줄 요약만 두고
  // 「개인정보 수집·이용 동의」를 받는 것은 동의로 성립하기 어렵다.
  testWidgets('개인정보 동의 항목에서 처리방침 전문으로 갈 수 있다', (tester) async {
    bigView(tester);
    final opener = _RecordingOpener();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [externalLinkOpenerProvider.overrideWithValue(opener)],
        child: _app(),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('consent-privacy-doc')));
    await tester.pump();

    expect(opener.opened, ['https://leva.ai.kr/privacy']);
  });

  // 전문을 「보려고」 누른 것이 「동의」가 되면 안 된다. trailing 버튼의 탭이
  // 타일까지 전달되면 정확히 그 일이 벌어진다.
  testWidgets('전문 링크를 눌러도 동의 체크는 켜지지 않는다', (tester) async {
    bigView(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          externalLinkOpenerProvider.overrideWithValue(_RecordingOpener()),
        ],
        child: _app(),
      ),
    );
    bool privacyChecked() => tester
        .widget<CheckboxListTile>(
          find.widgetWithText(CheckboxListTile, '개인정보 수집·이용 동의'),
        )
        .value!;

    await tester.tap(find.byKey(const ValueKey('consent-privacy-doc')));
    await tester.pump();

    expect(privacyChecked(), isFalse);

    // 같은 방법으로 읽은 값이 켜지기도 하는지 확인한다. 이게 없으면 위 단언은
    // 「언제나 false를 읽는 코드」로도 통과한다.
    await tester.tap(find.text('개인정보 수집·이용 동의'));
    await tester.pump();

    expect(privacyChecked(), isTrue);
  });

  // 「전문 보기」가 타일의 trailing 으로 들어가면서 좁은 폭에서 제목·설명과
  // 자리를 다툰다. 오버플로 예외로는 잡히지 않는다 — ListTile 이 텍스트를
  // 줄바꿈해 버려 200px 에서도 예외가 나지 않았다. 그래서 존재가 아니라
  // 「누를 수 있는가」를 본다. 버튼이 잘려 화면 밖으로 나가면 tap 이 실패한다.
  testWidgets('좁은 폭에서도 전문 링크를 누를 수 있다', (tester) async {
    tester.view.physicalSize = const Size(360, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final opener = _RecordingOpener();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [externalLinkOpenerProvider.overrideWithValue(opener)],
        child: _app(),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('consent-privacy-doc')));
    await tester.pump();

    expect(opener.opened, ['https://leva.ai.kr/privacy']);
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
