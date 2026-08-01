import 'package:devpath_web/src/features/community/data/community_source.dart';
import 'package:devpath_web/src/features/community/presentation/post_create_page.dart';
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/cupertino.dart';
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

    expect(find.text('자유글 작성'), findsOneWidget); // AppBar
    // 본문이 QuillEditor 로 바뀌어 TextField 는 제목/태그 2개만 남는다.
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.byType(QuillEditor), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '게시'), findsOneWidget);
  });

  testWidgets('FEEDBACK 프리셋: AppBar 라벨이 "피드백 요청"', (tester) async {
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
