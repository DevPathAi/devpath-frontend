import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:devpath_web/src/features/common/application/external_link_opener.dart';
import 'package:devpath_web/src/features/consent/application/consent_controller.dart';
import 'package:devpath_web/src/features/consent/application/consent_source.dart';
import 'package:devpath_web/src/features/consent/presentation/consent_page.dart';
import 'package:devpath_web/src/features/consent/state/consent_state.dart';
import 'package:devpath_web/src/features/settings/data/settings_models.dart';

MaterialApp _app() =>
    MaterialApp(theme: DpTheme.light(), home: const ConsentPage());

/// prefill 조회(GET /consents/me) 응답을 즉시 확정값으로 주입한다. 실네트워크 없이
/// consentPrefillProvider의 AsyncValue를 결정적으로 만든다.
/// 반환 타입을 `dynamic`으로 둔다 — 이 riverpod 버전은 `Override`를 공개 API로
/// export하지 않아(내부 sealed 타입) 이 파일에서 그 이름을 쓸 수 없다.
List<dynamic> _prefill(ConsentsView view) => [
  consentPrefillProvider.overrideWith((ref) async => view),
];

/// 신규 가입자: 동의 이력 없음(items 빈 목록).
ConsentsView _newUserPrefill() =>
    const ConsentsView(consentStatus: 'PENDING', items: []);

/// 기존 이용자: 이전에 TERMS·PRIVACY·MARKETING 모두 동의했던 이력 + 생년.
/// 재동의 화면에서도 필수 2종은 항상 false로 시작해야 하므로, 여기서는 일부러
/// agreed:true인 채로 넣어 "정말로 무시하는지"를 검증할 수 있게 한다.
ConsentsView _returningUserPrefill() => const ConsentsView(
  consentStatus: 'PENDING',
  items: [
    ConsentItemView(type: 'TERMS', agreed: true, version: '1.0'),
    ConsentItemView(type: 'PRIVACY', agreed: true, version: '1.0'),
    ConsentItemView(type: 'MARKETING', agreed: true, version: '1.0'),
  ],
  birthYear: 1998,
);

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
    await tester.pumpWidget(
      ProviderScope(overrides: [..._prefill(_newUserPrefill())], child: _app()),
    );
    await tester.pumpAndSettle();

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
    await tester.pumpWidget(
      ProviderScope(overrides: [..._prefill(_newUserPrefill())], child: _app()),
    );
    await tester.pumpAndSettle();

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
        overrides: [
          consentControllerProvider.overrideWith(() => recorder),
          ..._prefill(_newUserPrefill()),
        ],
        child: _app(),
      ),
    );
    await tester.pumpAndSettle();

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
        overrides: [
          consentControllerProvider.overrideWith(() => recorder),
          ..._prefill(_newUserPrefill()),
        ],
        child: _app(),
      ),
    );
    await tester.pumpAndSettle();

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
        overrides: [
          consentControllerProvider.overrideWith(() => recorder),
          ..._prefill(_newUserPrefill()),
        ],
        child: _app(),
      ),
    );
    await tester.pumpAndSettle();

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
        overrides: [
          consentControllerProvider.overrideWith(() => recorder),
          ..._prefill(_newUserPrefill()),
        ],
        child: _app(),
      ),
    );
    await tester.pumpAndSettle();

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
        overrides: [
          externalLinkOpenerProvider.overrideWithValue(opener),
          ..._prefill(_newUserPrefill()),
        ],
        child: _app(),
      ),
    );
    await tester.pumpAndSettle();

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
          ..._prefill(_newUserPrefill()),
        ],
        child: _app(),
      ),
    );
    await tester.pumpAndSettle();
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
        overrides: [
          externalLinkOpenerProvider.overrideWithValue(opener),
          ..._prefill(_newUserPrefill()),
        ],
        child: _app(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('consent-privacy-doc')));
    await tester.pump();

    expect(opener.opened, ['https://leva.ai.kr/privacy']);
  });

  testWidgets('약관 전문 링크가 약관 페이지를 연다', (tester) async {
    bigView(tester);
    final opener = _RecordingOpener();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          externalLinkOpenerProvider.overrideWithValue(opener),
          ..._prefill(_newUserPrefill()),
        ],
        child: _app(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('consent-terms-doc')));
    await tester.pump();

    expect(opener.opened, ['https://leva.ai.kr/terms']);
  });

  testWidgets('ConsentBlocked → 차단 안내 + 로그아웃 버튼 + 재시도 안내', (tester) async {
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
    // I-3: 출생 연도 오타로 400을 받은 기존 이용자도 이 화면을 본다. 로그아웃
    // 버튼만 있으면 "계정이 잘렸다"는 신호로 읽힌다 — 재시도 경로를 안내한다.
    expect(find.text('출생 연도를 잘못 입력하셨다면 다시 로그인해 재시도할 수 있습니다.'), findsOneWidget);
  });

  // I-2: 재동의 화면은 기존 선택 동의를 불러와 미리 반영해야 한다. 그렇지 않으면
  // MARKETING 등에 이미 동의한 이용자가 재동의 화면에서 다시 체크하지 않는 한
  // "동의 안 함"으로 제출돼 조용히 철회된 것처럼 기록된다.
  testWidgets('기존 선택 동의(MARKETING)가 있으면 체크된 상태로 시작한다', (tester) async {
    bigView(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [..._prefill(_returningUserPrefill())],
        child: _app(),
      ),
    );
    await tester.pumpAndSettle();

    final marketing = tester
        .widget<CheckboxListTile>(
          find.widgetWithText(CheckboxListTile, '마케팅 정보 수신 동의'),
        )
        .value;

    expect(marketing, isTrue);
  });

  // 재동의의 목적은 "다시 받는 것"이다. 서버가 이전에 TERMS·PRIVACY에 agreed:true를
  // 돌려줘도, 필수 2종은 항상 꺼진 채로 시작해야 한다.
  testWidgets('기존 동의가 있어도 필수 2종은 꺼진 상태로 시작한다', (tester) async {
    bigView(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [..._prefill(_returningUserPrefill())],
        child: _app(),
      ),
    );
    await tester.pumpAndSettle();

    bool checkedOf(String label) => tester
        .widget<CheckboxListTile>(find.widgetWithText(CheckboxListTile, label))
        .value!;

    expect(checkedOf('서비스 이용약관 동의'), isFalse);
    expect(checkedOf('개인정보 수집·이용 동의'), isFalse);
  });

  testWidgets('birthYear가 있으면 입력란에 채워진다', (tester) async {
    bigView(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [..._prefill(_returningUserPrefill())],
        child: _app(),
      ),
    );
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, '1998');
  });

  testWidgets('기존 동의 이력이 있으면 재동의 문구가 보인다', (tester) async {
    bigView(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [..._prefill(_returningUserPrefill())],
        child: _app(),
      ),
    );
    await tester.pumpAndSettle();

    final header = tester.widget<DpPageHeader>(find.byType(DpPageHeader));
    expect(header.title, '서비스 이용약관 재동의');
    expect(header.description, '약관이 새로 게시되어 다시 동의를 받습니다');
  });

  testWidgets('기존 동의 이력이 없으면(신규) 가입 전 동의 문구를 유지한다', (tester) async {
    bigView(tester);
    await tester.pumpWidget(
      ProviderScope(overrides: [..._prefill(_newUserPrefill())], child: _app()),
    );
    await tester.pumpAndSettle();

    final header = tester.widget<DpPageHeader>(find.byType(DpPageHeader));
    expect(header.title, '가입 전 동의');
    expect(header.description, '서비스 이용에 필요한 항목입니다');
  });

  // prefill 조회 실패로 화면이 막히면 재동의 자체가 불가능해진다 — 신규 가입자와
  // 같은 빈 폼으로 폴백해 제출은 계속 가능해야 한다.
  testWidgets('prefill 조회가 실패해도 폼이 렌더되고 제출할 수 있다', (tester) async {
    bigView(tester);
    final recorder = _RecordingController();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          consentControllerProvider.overrideWith(() => recorder),
          consentPrefillProvider.overrideWith(
            (ref) async => throw Exception('network down'),
          ),
        ],
        child: _app(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(FilledButton), findsOneWidget);

    await tester.tap(find.text('서비스 이용약관 동의'));
    await tester.tap(find.text('개인정보 수집·이용 동의'));
    await tester.enterText(find.byType(TextField), '2000');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '동의하고 계속하기'));
    await tester.pump();

    expect(recorder.submits, 1);
  });
}
