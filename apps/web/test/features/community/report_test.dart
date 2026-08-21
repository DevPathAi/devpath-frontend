import 'package:devpath_web/src/features/community/data/community_source.dart';
import 'package:devpath_web/src/features/community/presentation/widgets/content_menu_button.dart';
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ProviderContainer _containerWith({CommunityReportSubmit? submit}) {
  final c = ProviderContainer(
    overrides: [
      if (submit != null) communityReportProvider.overrideWithValue(submit),
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

/// 다이얼로그를 열기까지의 공통 절차.
Future<void> _openDialog(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('content-menu')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('신고하기'));
  await tester.pumpAndSettle();
}

void main() {
  // ★계약이 바뀌었다★ — 내 콘텐츠에서도 메뉴는 보인다. 항목이 신고 대신 수정·삭제로
  // 바뀔 뿐이다. 그 분기 자체는 content_menu_test.dart 가 검증한다.
  testWidgets('자기 콘텐츠에는 신고 항목이 없다', (tester) async {
    await tester.pumpWidget(
      _host(
        _containerWith(),
        const ContentMenuButton(
          kind: ContentKind.post,
          targetId: 1,
          authorId: 7,
          currentUserId: '7',
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('content-menu')));
    await tester.pumpAndSettle();

    expect(find.text('신고하기'), findsNothing);
  });

  testWidgets('남의 콘텐츠에는 메뉴가 보인다', (tester) async {
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
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('content-menu')), findsOneWidget);
  });

  testWidgets('작성자를 모르면 메뉴를 보여준다(신고 가능)', (tester) async {
    await tester.pumpWidget(
      _host(
        _containerWith(),
        const ContentMenuButton(
          kind: ContentKind.post,
          targetId: 1,
          authorId: null,
          currentUserId: '3',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('content-menu')), findsOneWidget);
  });

  testWidgets('카테고리를 고르고 신고하면 wire 값과 사유가 전달된다', (tester) async {
    String? sentType;
    int? sentId;
    CommunityReportCategory? sentCategory;
    String? sentReason;
    final c = _containerWith(
      submit:
          ({
            required String targetType,
            required int targetId,
            required CommunityReportCategory category,
            String? reason,
          }) async {
            sentType = targetType;
            sentId = targetId;
            sentCategory = category;
            sentReason = reason;
            return const CommunityReportResult(id: 5, status: 'OPEN');
          },
    );
    await tester.pumpWidget(
      _host(
        c,
        const ContentMenuButton(
          kind: ContentKind.answer,
          targetId: 11,
          authorId: 7,
          currentUserId: '3',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _openDialog(tester);
    await tester.tap(find.text('욕설'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('report-reason')),
      '심한 표현',
    );
    await tester.tap(find.byKey(const ValueKey('report-submit')));
    await tester.pumpAndSettle();

    expect(sentType, 'ANSWER');
    expect(sentId, 11);
    expect(sentCategory, CommunityReportCategory.abuse);
    expect(sentReason, '심한 표현');
    expect(find.textContaining('접수'), findsOneWidget);
  });

  testWidgets('이미 신고한 대상이면 409 안내를 보여준다', (tester) async {
    final c = _containerWith(
      submit:
          ({
            required String targetType,
            required int targetId,
            required CommunityReportCategory category,
            String? reason,
          }) async => throw const ApiException(
            code: ApiErrorCode.conflict,
            message: '이미 신고한 콘텐츠입니다.',
          ),
    );
    await tester.pumpWidget(
      _host(
        c,
        const ContentMenuButton(
          kind: ContentKind.post,
          targetId: 1,
          authorId: 7,
          currentUserId: '3',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _openDialog(tester);
    await tester.tap(find.text('스팸'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('report-submit')));
    await tester.pumpAndSettle();

    expect(find.textContaining('이미 신고'), findsOneWidget);
  });

  testWidgets('본인 콘텐츠 400 은 전용 문구로 안내한다', (tester) async {
    final c = _containerWith(
      submit:
          ({
            required String targetType,
            required int targetId,
            required CommunityReportCategory category,
            String? reason,
          }) async => throw const ApiException(
            code: ApiErrorCode.validationFailed,
            message: '본인이 작성한 콘텐츠는 신고할 수 없습니다.',
          ),
    );
    await tester.pumpWidget(
      _host(
        c,
        const ContentMenuButton(
          kind: ContentKind.post,
          targetId: 1,
          authorId: null,
          currentUserId: '3',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _openDialog(tester);
    await tester.tap(find.text('스팸'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('report-submit')));
    await tester.pumpAndSettle();

    expect(find.textContaining('본인'), findsOneWidget);
  });

  testWidgets('카테고리를 고르지 않으면 신고 버튼이 비활성이다', (tester) async {
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
    await tester.pumpAndSettle();

    await _openDialog(tester);

    final button = tester.widget<FilledButton>(
      find.byKey(const ValueKey('report-submit')),
    );
    expect(button.onPressed, isNull, reason: '조용히 실패하는 버튼을 만들지 않는다');
  });
}
