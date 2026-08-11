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

  // scrollable: false 라 내용이 길면 위젯 자체가 커진다. 내부 스크롤이 남아
  // 있으면 높이가 최소값에 고정돼 이 단언이 실패한다.
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
