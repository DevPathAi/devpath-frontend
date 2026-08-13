import 'package:devpath_web/src/features/community/presentation/widgets/rich_editor.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(QuillController controller) => MaterialApp(
  theme: DpTheme.light(),
  localizationsDelegates: const [
    DefaultCupertinoLocalizations.delegate,
    DefaultMaterialLocalizations.delegate,
    DefaultWidgetsLocalizations.delegate,
    FlutterQuillLocalizations.delegate,
  ],
  home: Scaffold(body: DpRichEditor(controller: controller)),
);

void main() {
  testWidgets('툴바와 에디터를 렌더한다', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final c = QuillController.basic();
    addTearDown(c.dispose);

    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();

    expect(find.byType(QuillSimpleToolbar), findsOneWidget);
    expect(find.byType(QuillEditor), findsOneWidget);
  });

  testWidgets('마크다운 비표현 서식 버튼을 노출하지 않는다', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final c = QuillController.basic();
    addTearDown(c.dispose);

    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();

    // 색/폰트/정렬/검색 등은 화이트리스트에서 제외됐다.
    expect(find.byType(QuillToolbarColorButton), findsNothing);
    expect(find.byType(QuillToolbarFontFamilyButton), findsNothing);
    expect(find.byType(QuillToolbarFontSizeButton), findsNothing);
    expect(find.byType(QuillToolbarSearchButton), findsNothing);
  });

  testWidgets('enabled=false 면 입력을 흡수한다', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final c = QuillController.basic();
    addTearDown(c.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: DpTheme.light(),
        localizationsDelegates: const [
          DefaultCupertinoLocalizations.delegate,
          DefaultMaterialLocalizations.delegate,
          DefaultWidgetsLocalizations.delegate,
          FlutterQuillLocalizations.delegate,
        ],
        home: Scaffold(body: DpRichEditor(controller: c, enabled: false)),
      ),
    );
    await tester.pumpAndSettle();

    final absorber = tester.widget<AbsorbPointer>(
      find
          .descendant(
            of: find.byType(DpRichEditor),
            matching: find.byType(AbsorbPointer),
          )
          .first,
    );
    expect(absorber.absorbing, isTrue);
  });

  // 라이브러리가 toolbarSize를 private으로 막아 두어 실측값을 상수로 쓴다.
  // 버전이 올라 높이가 바뀌면 여기서 red가 나 sliver 높이도 함께 고쳐야 함을 안다.
  testWidgets('툴바 실제 높이가 상수와 일치한다', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final c = QuillController.basic();
    addTearDown(c.dispose);

    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byType(QuillSimpleToolbar)).height,
      kDpRichEditorToolbarHeight,
    );
  });

  testWidgets('빈 문서에서도 본문이 최소 높이를 지킨다', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final c = QuillController.basic();
    addTearDown(c.dispose);

    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byType(DpRichEditorBody)).height,
      greaterThanOrEqualTo(260.0),
    );
  });

  // ★캐럿 추적 가드★
  //
  // scrollable: false 로 두면 에디터가 자체 스크롤을 만들지 않아 우리가 준
  // ScrollController 에 클라이언트가 붙지 않는다. flutter_quill 의
  // bringIntoView 는 `if (scrollController.hasClients) jumpTo(...)` 로 캐럿을
  // 좇는데, 그 조건이 거짓이 되어 **타이핑 중 커서가 화면 밖으로 나가도 아무도
  // 따라가지 않았다**(사용자 실측). 남은 showOnScreen 경로는 확장 모드에서
  // 동작하지 않는다고 라이브러리 문서가 밝히고 있다.
  //
  // 자체 스크롤을 유지하되 maxHeight 를 크게 둬 「내용만큼 늘어남」을 함께
  // 얻는다. 이 테스트는 자체 스크롤이 살아 있는지를 본다.
  testWidgets('커서를 문서 끝으로 옮기면 에디터가 따라 스크롤한다', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // maxHeight를 작게 줘 내부 스크롤이 생기게 한다(운영 기본값 2000으로는
    // 이 문서가 다 들어가 자체 스크롤이 만들어지지 않는다).
    final text = List.filled(60, '긴 본문 줄입니다.').join('\n');
    final doc = Document()..insert(0, text);
    final c = QuillController(
      document: doc,
      selection: const TextSelection.collapsed(offset: 0),
    );
    addTearDown(c.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: DpTheme.light(),
        localizationsDelegates: const [
          DefaultCupertinoLocalizations.delegate,
          DefaultMaterialLocalizations.delegate,
          DefaultWidgetsLocalizations.delegate,
          FlutterQuillLocalizations.delegate,
        ],
        home: Scaffold(
          body: DpRichEditor(controller: c, minHeight: 200, maxHeight: 300),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final editorScroll = tester
        .state<ScrollableState>(
          find
              .descendant(
                of: find.byType(QuillEditor),
                matching: find.byType(Scrollable),
              )
              .first,
        )
        .position;

    expect(editorScroll.pixels, 0, reason: '시작은 문서 맨 위여야 한다');

    c.updateSelection(
      TextSelection.collapsed(offset: text.length),
      ChangeSource.local,
    );
    await tester.pumpAndSettle();

    expect(
      editorScroll.pixels,
      greaterThan(0),
      reason: '자체 스크롤이 없으면 캐럿을 좇지 못한다(pixels=${editorScroll.pixels})',
    );
  });

  // 내용이 길면 위젯 자체가 커진다(maxHeight까지). 높이가 최소값에 고정되면
  // 이 단언이 실패한다.
  testWidgets('내용이 길면 본문이 최소 높이보다 커진다', (tester) async {
    tester.view.physicalSize = const Size(1400, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final doc = Document()..insert(0, List.filled(80, '긴 본문 줄입니다.').join('\n'));
    final c = QuillController(
      document: doc,
      selection: const TextSelection.collapsed(offset: 0),
    );
    addTearDown(c.dispose);

    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byType(DpRichEditorBody)).height,
      greaterThan(260.0),
    );
  });
}
