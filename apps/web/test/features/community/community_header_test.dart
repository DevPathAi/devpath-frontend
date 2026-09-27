import 'package:devpath_web/src/features/community/presentation/community_home_page.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('커뮤니티 홈은 AppBar 대신 sliver 헤더를 쓴다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: DpTheme.light(),
          home: const CommunityHomePage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(AppBar), findsNothing);
    final header = tester.widget<DpPageHeader>(find.byType(DpPageHeader));
    expect(header.title, '자유게시판');
    expect(header.description, '개발 이야기를 자유롭게 나눕니다');
    expect(find.byType(PinnedHeaderSliver), findsOneWidget);
    // S3-P3: 시안에 FAB 이 없다 — 주요 액션은 페이지 헤더 우측 버튼이다.
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.widgetWithText(FilledButton, '글 작성'), findsOneWidget);
  });
}
