import 'package:devpath_web/src/features/community/data/community_source.dart';
import 'package:devpath_web/src/features/community/presentation/post_create_page.dart';
import 'package:devpath_web/src/features/community/presentation/widgets/rich_editor.dart';
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

CommunityPostDetail _created(int id, String board) =>
    CommunityPostDetail(id: id, boardType: board, title: '새 글', bodyMd: '본문');

/// 본문 문서를 미리 채운 컨트롤러(에디터 입력 시뮬레이션 대체).
QuillController _bodyWith(String text) {
  final doc = Document()..insert(0, text);
  return QuillController(
    document: doc,
    selection: const TextSelection.collapsed(offset: 0),
  );
}

Widget _host(
  ProviderContainer c, {
  String board = 'FREE',
  QuillController? bodyController,
}) {
  final router = GoRouter(
    initialLocation: '/community/new/post',
    routes: [
      GoRoute(
        path: '/community/new/post',
        builder: (_, _) =>
            PostCreatePage(board: board, bodyController: bodyController),
      ),
      GoRoute(
        path: '/community/post/:id',
        builder: (_, state) => Text('상세: ${state.pathParameters['id']}'),
      ),
    ],
  );
  return UncontrolledProviderScope(
    container: c,
    child: MaterialApp.router(
      theme: DpTheme.light(),
      localizationsDelegates: const [
        DefaultCupertinoLocalizations.delegate,
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
        FlutterQuillLocalizations.delegate,
      ],
      routerConfig: router,
    ),
  );
}

void _wideView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1400, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('FREE 프리셋: 제목/태그 TextField + 본문 에디터 + 게시 버튼 렌더', (tester) async {
    _wideView(tester);
    final c = ProviderContainer(
      overrides: [
        postCreateProvider.overrideWithValue(
          ({
            required boardType,
            required title,
            required bodyMd,
            required tags,
          }) async => _created(30, boardType),
        ),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();

    expect(find.text('자유글 작성'), findsOneWidget); // 페이지 헤더
    // 본문이 QuillEditor 로 바뀌어 TextField 는 제목/태그 2개만 남는다.
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.byType(QuillEditor), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '게시'), findsOneWidget);
  });

  testWidgets('게시 버튼이 콘텐츠 폭을 꽉 채우지 않는다', (tester) async {
    // FilledButton.icon이 SliverList.list의 직접 자식이면 가로로 늘어나
    // 넓은 화면에서 버튼 하나가 콘텐츠 폭 전체를 차지한다(3-A 보고서 §4-2:
    // 1400폭에서 약 1110px). 액션 버튼은 자기 콘텐츠 크기여야 한다.
    _wideView(tester);
    final c = ProviderContainer(
      overrides: [
        postCreateProvider.overrideWithValue(
          ({
            required boardType,
            required title,
            required bodyMd,
            required tags,
          }) async => _created(30, boardType),
        ),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();

    // 콘텐츠 폭과 비교하려 해도 `find.byType(CustomScrollView)`는 쓸 수 없다 —
    // flutter_quill 툴바가 내부에 하나 더 만들어 2개가 매치된다(3-A Task 11 실측).
    // 아이콘+「게시」 두 글자짜리 버튼이므로 절대값으로 충분히 갈린다.
    final button = tester.getSize(find.widgetWithText(FilledButton, '게시'));
    expect(
      button.width,
      lessThan(300),
      reason: '늘어나면 콘텐츠 폭 전체(3-A 실측 약 1110px)를 차지한다',
    );
  });

  // 에디터가 고정 높이 자체 스크롤이면 커서가 본문 위에 있을 때 휠을 흡수해
  // 페이지가 멈춘다. 화면이 고장난 것처럼 보인다.
  //
  // ★본문을 길게 주는 것이 이 테스트의 핵심이다.★ 짧은 본문이면 콘텐츠 전체가
  // 뷰포트(800)에 들어가 스크롤할 것이 없고, 그러면 고치기 전과 후가 똑같이
  // "안 움직인다"로 나와 수정 여부를 구별하지 못한다. 길게 주면 고치기 전에는
  // 에디터가 260에 고정돼 페이지가 짧고(=흡수해도 움직일 것이 없음이 아니라
  // 흡수해서 안 움직임), 고친 뒤에는 에디터가 늘어나 페이지가 스크롤된다.
  testWidgets('에디터 위에서 휠을 굴리면 페이지가 스크롤된다', (tester) async {
    tester.view.physicalSize = const Size(1400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final c = ProviderContainer(
      overrides: [
        postCreateProvider.overrideWithValue(
          ({
            required boardType,
            required title,
            required bodyMd,
            required tags,
          }) async => _created(30, boardType),
        ),
      ],
    );
    addTearDown(c.dispose);
    final body = _bodyWith(List.filled(60, '긴 본문 줄입니다.').join('\n'));
    addTearDown(body.dispose);

    await tester.pumpWidget(_host(c, bodyController: body));
    await tester.pumpAndSettle();

    // 위젯 좌표로 재면 안 된다 — 페이지가 실제로 스크롤되면 헤더가 뷰포트 밖으로
    // 나가고 sliver가 그 자식을 제거해, 성공했을 때 오히려 좌표를 못 잰다.
    // 페이지 스크롤 위치를 직접 읽는다. Scrollable은 flutter_quill 툴바가
    // 내부에 더 만들어 여러 개이므로 헤더를 품은 것을 지목한다.
    final page = tester
        .state<ScrollableState>(
          find
              .ancestor(
                of: find.text('자유글 작성'),
                matching: find.byType(Scrollable),
              )
              .first,
        )
        .position;
    final before = page.pixels;

    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    pointer.hover(tester.getCenter(find.byType(QuillEditor)));
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, 300)));
    await tester.pumpAndSettle();

    final after = page.pixels;

    expect(
      after,
      greaterThan(before),
      reason: '에디터가 휠을 흡수하면 페이지가 제자리다(before=$before after=$after)',
    );
  });

  // 에디터가 늘어나면 툴바가 본문과 함께 위로 사라진다. 긴 글을 쓰는 동안
  // 서식 버튼에 닿으려면 매번 올라가야 하므로 상단에 고정한다.
  testWidgets('페이지를 스크롤해도 툴바가 화면에 남는다', (tester) async {
    tester.view.physicalSize = const Size(1400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final c = ProviderContainer(
      overrides: [
        postCreateProvider.overrideWithValue(
          ({
            required boardType,
            required title,
            required bodyMd,
            required tags,
          }) async => _created(30, boardType),
        ),
      ],
    );
    addTearDown(c.dispose);
    final body = _bodyWith(List.filled(60, '긴 본문 줄입니다.').join('\n'));
    addTearDown(body.dispose);

    await tester.pumpWidget(_host(c, bodyController: body));
    await tester.pumpAndSettle();

    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    pointer.hover(tester.getCenter(find.byType(QuillEditor)));
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, 400)));
    await tester.pumpAndSettle();

    // 고정돼 있으면 화면 안에 남는다. 함께 스크롤되면 sliver가 제거하거나
    // 음수 좌표로 밀려난다.
    expect(find.byType(DpRichEditorToolbar), findsOneWidget);
    final top = tester.getTopLeft(find.byType(DpRichEditorToolbar)).dy;
    expect(top, greaterThanOrEqualTo(0.0), reason: '툴바가 위로 밀려났다(top=$top)');
  });

  // ★알려진 부작용을 문서화한다.★ pinned 헤더는 뒤따르는 sliver가 스크롤되는
  // 동안 계속 상단에 붙어 있고, 다음 pinned 헤더가 밀어내야 사라진다. 이 화면엔
  // 그런 게 없어 본문을 지나 태그·버튼 영역에서도 툴바가 남는다.
  // 의도한 동작은 아니지만 수용한 상태다 — 바꾸려면 이 테스트가 먼저 red가 된다.
  testWidgets('본문을 지나서도 툴바가 남는다(수용한 부작용)', (tester) async {
    tester.view.physicalSize = const Size(1400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final c = ProviderContainer(
      overrides: [
        postCreateProvider.overrideWithValue(
          ({
            required boardType,
            required title,
            required bodyMd,
            required tags,
          }) async => _created(30, boardType),
        ),
      ],
    );
    addTearDown(c.dispose);
    final body = _bodyWith(List.filled(60, '긴 본문 줄입니다.').join('\n'));
    addTearDown(body.dispose);

    await tester.pumpWidget(_host(c, bodyController: body));
    await tester.pumpAndSettle();

    // 본문 끝을 지나 게시 버튼이 보일 때까지 충분히 내린다.
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    pointer.hover(tester.getCenter(find.byType(QuillEditor)));
    for (var i = 0; i < 6; i++) {
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, 400)));
      await tester.pumpAndSettle();
    }

    expect(find.widgetWithText(FilledButton, '게시'), findsOneWidget);
    expect(
      find.byType(DpRichEditorToolbar),
      findsOneWidget,
      reason: '본문을 벗어난 위치에서도 툴바가 남아 있다(수용한 부작용)',
    );
  });

  testWidgets('FEEDBACK 프리셋: 페이지 헤더 라벨이 "피드백 요청"', (tester) async {
    _wideView(tester);
    final c = ProviderContainer(
      overrides: [
        postCreateProvider.overrideWithValue(
          ({
            required boardType,
            required title,
            required bodyMd,
            required tags,
          }) async => _created(31, boardType),
        ),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(_host(c, board: 'FEEDBACK'));
    await tester.pumpAndSettle();

    expect(find.text('피드백 요청'), findsOneWidget);
  });

  // 3-A Task 14-3: 헤더 설명과 본문 안내가 사실상 같은 말이었다(2단계 계획이 헤더
  // 문구를 지정하면서 본문 수정을 금지해 생긴 결과). 더 눈에 띄는 자리인 헤더를
  // 남기고 본문 안내를 지운다. 헤더 문구는 2단계 스펙 §5가 지정한 값이라 불변이다.
  testWidgets('본문 안내가 헤더 설명과 중복되지 않는다 (FREE·FEEDBACK)', (tester) async {
    _wideView(tester);
    for (final board in ['FREE', 'FEEDBACK']) {
      final c = ProviderContainer(
        overrides: [
          postCreateProvider.overrideWithValue(
            ({
              required boardType,
              required title,
              required bodyMd,
              required tags,
            }) async => _created(32, boardType),
          ),
        ],
      );
      addTearDown(c.dispose);
      await tester.pumpWidget(_host(c, board: board));
      await tester.pumpAndSettle();

      expect(
        tester.widget<DpPageHeader>(find.byType(DpPageHeader)).description,
        '자유롭게 쓰거나 코드 피드백을 요청하세요',
        reason: '2단계 스펙 §5가 지정한 헤더 설명은 불변이다 (board=$board)',
      );
      expect(find.text('나누고 싶은 이야기를 적어주세요'), findsNothing);
      expect(find.text('리뷰받고 싶은 코드/프로젝트와 궁금한 점을 적어주세요'), findsNothing);
    }
  });

  testWidgets('제목·본문 입력 후 게시하면 postCreate(boardType) 호출 + 상세로 이동', (
    tester,
  ) async {
    _wideView(tester);
    String? seenBoard, seenTitle, seenBody;
    List<String>? seenTags;
    final body = _bodyWith('본문 내용');
    addTearDown(body.dispose);
    final c = ProviderContainer(
      overrides: [
        postCreateProvider.overrideWithValue(({
          required String boardType,
          required String title,
          required String bodyMd,
          required List<String> tags,
        }) async {
          seenBoard = boardType;
          seenTitle = title;
          seenBody = bodyMd;
          seenTags = tags;
          return _created(30, boardType);
        }),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(_host(c, bodyController: body));
    await tester.pumpAndSettle();

    // 인덱스 재배치: 0=제목, 1=태그 (본문은 controller 주입)
    await tester.enterText(find.byType(TextField).at(0), '새 자유글');
    await tester.enterText(find.byType(TextField).at(1), 'dart, async');

    await tester.tap(find.widgetWithText(FilledButton, '게시'));
    await tester.pumpAndSettle();

    expect(seenBoard, 'FREE');
    expect(seenTitle, '새 자유글');
    expect(seenBody, '본문 내용'); // 평문은 마크다운 변환 후에도 동일
    expect(seenTags, ['dart', 'async']);
    expect(find.text('상세: 30'), findsOneWidget);
  });

  testWidgets('제목/본문 비면 게시하지 않고 안내', (tester) async {
    _wideView(tester);
    var createCalls = 0;
    final c = ProviderContainer(
      overrides: [
        postCreateProvider.overrideWithValue(({
          required String boardType,
          required String title,
          required String bodyMd,
          required List<String> tags,
        }) async {
          createCalls++;
          return _created(30, boardType);
        }),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, '게시'));
    await tester.pumpAndSettle();

    expect(createCalls, 0);
    expect(find.textContaining('제목과 본문'), findsOneWidget);
  });

  testWidgets('본문에 서식이 있으면 마크다운으로 변환돼 저장된다', (tester) async {
    _wideView(tester);
    String? seenBody;
    final doc = Document()..insert(0, '굵게');
    doc.format(0, 2, Attribute.bold);
    final body = QuillController(
      document: doc,
      selection: const TextSelection.collapsed(offset: 0),
    );
    addTearDown(body.dispose);
    final c = ProviderContainer(
      overrides: [
        postCreateProvider.overrideWithValue(({
          required String boardType,
          required String title,
          required String bodyMd,
          required List<String> tags,
        }) async {
          seenBody = bodyMd;
          return _created(30, boardType);
        }),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(_host(c, bodyController: body));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), '제목');
    await tester.tap(find.widgetWithText(FilledButton, '게시'));
    await tester.pumpAndSettle();

    // Task 1 Step 4 관찰값(굵게)과 동일해야 한다.
    expect(seenBody, '**굵게**');
  });
}
