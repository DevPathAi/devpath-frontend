import 'package:devpath_web/src/features/community/data/community_source.dart';
import 'package:devpath_web/src/features/community/presentation/widgets/content_menu_button.dart';
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ProviderContainer _containerWith({
  PostDelete? postDelete,
  AnswerDelete? answerDelete,
}) {
  final c = ProviderContainer(
    overrides: [
      if (postDelete != null) postDeleteProvider.overrideWithValue(postDelete),
      if (answerDelete != null)
        answerDeleteProvider.overrideWithValue(answerDelete),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

Widget _host(ProviderContainer c, Widget child) => UncontrolledProviderScope(
  container: c,
  child: MaterialApp(
    theme: DpTheme.light(),
    home: Scaffold(body: child),
  ),
);

Future<void> _openMenu(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('content-menu')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('내 콘텐츠에는 수정·삭제가 보이고 신고는 없다', (tester) async {
    await tester.pumpWidget(
      _host(
        _containerWith(),
        ContentMenuButton(
          kind: ContentKind.post,
          targetId: 1,
          authorId: 7,
          currentUserId: '7',
          onEdit: () {},
        ),
      ),
    );
    await _openMenu(tester);

    expect(find.text('수정하기'), findsOneWidget);
    expect(find.text('삭제하기'), findsOneWidget);
    expect(find.text('신고하기'), findsNothing);
  });

  testWidgets('남의 콘텐츠에는 신고만 보인다', (tester) async {
    await tester.pumpWidget(
      _host(
        _containerWith(),
        const ContentMenuButton(
          kind: ContentKind.post,
          targetId: 1,
          authorId: 7,
          currentUserId: '3',
        ),
      ),
    );
    await _openMenu(tester);

    expect(find.text('신고하기'), findsOneWidget);
    expect(find.text('삭제하기'), findsNothing);
  });

  testWidgets('작성자를 모르면 남의 것으로 본다 — 신고만 보인다', (tester) async {
    await tester.pumpWidget(
      _host(
        _containerWith(),
        const ContentMenuButton(
          kind: ContentKind.answer,
          targetId: 11,
          authorId: null,
          currentUserId: '3',
        ),
      ),
    );
    await _openMenu(tester);

    expect(find.text('신고하기'), findsOneWidget);
    expect(find.text('수정하기'), findsNothing);
  });

  testWidgets('onEdit 이 없으면 수정 항목을 내지 않는다', (tester) async {
    await tester.pumpWidget(
      _host(
        _containerWith(),
        const ContentMenuButton(
          kind: ContentKind.comment,
          targetId: 5,
          authorId: 7,
          currentUserId: '7',
        ),
      ),
    );
    await _openMenu(tester);

    expect(find.text('수정하기'), findsNothing);
    expect(find.text('삭제하기'), findsOneWidget);
  });

  testWidgets('삭제는 확인을 거치고 취소하면 호출하지 않는다', (tester) async {
    var called = false;
    await tester.pumpWidget(
      _host(
        _containerWith(postDelete: (id) async => called = true),
        const ContentMenuButton(
          kind: ContentKind.post,
          targetId: 1,
          authorId: 7,
          currentUserId: '7',
        ),
      ),
    );
    await _openMenu(tester);
    await tester.tap(find.text('삭제하기'));
    await tester.pumpAndSettle();

    expect(find.text('삭제하면 되돌릴 수 없어요.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('content-delete-cancel')));
    await tester.pumpAndSettle();

    expect(called, isFalse);
  });

  testWidgets('확인하면 삭제하고 onDeleted 를 부른다', (tester) async {
    var deletedId = 0;
    var notified = false;
    await tester.pumpWidget(
      _host(
        _containerWith(postDelete: (id) async => deletedId = id),
        ContentMenuButton(
          kind: ContentKind.post,
          targetId: 42,
          authorId: 7,
          currentUserId: '7',
          onDeleted: () => notified = true,
        ),
      ),
    );
    await _openMenu(tester);
    await tester.tap(find.text('삭제하기'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('content-delete-confirm')));
    await tester.pumpAndSettle();

    expect(deletedId, 42);
    expect(notified, isTrue);
  });

  testWidgets('채택된 답변 409 는 전용 문구로 안내한다', (tester) async {
    await tester.pumpWidget(
      _host(
        _containerWith(
          answerDelete: (id) async => throw const ApiException(
            code: ApiErrorCode.conflict,
            message: '채택된 답변입니다.',
          ),
        ),
        const ContentMenuButton(
          kind: ContentKind.answer,
          targetId: 11,
          authorId: 7,
          currentUserId: '7',
        ),
      ),
    );
    await _openMenu(tester);
    await tester.tap(find.text('삭제하기'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('content-delete-confirm')));
    await tester.pumpAndSettle();

    expect(find.text('채택된 답변은 채택을 먼저 해제해 주세요'), findsOneWidget);
  });

  test('에러 문구 매핑 4종', () {
    String m(ApiErrorCode c) =>
        contentActionMessage(ApiException(code: c, message: 'x'));

    expect(m(ApiErrorCode.forbidden), '내가 쓴 글만 수정할 수 있어요');
    expect(m(ApiErrorCode.resourceNotFound), '이미 삭제된 콘텐츠예요');
    expect(m(ApiErrorCode.conflict), '채택된 답변은 채택을 먼저 해제해 주세요');
    expect(m(ApiErrorCode.validationFailed), '내용을 입력해 주세요');
  });
}
