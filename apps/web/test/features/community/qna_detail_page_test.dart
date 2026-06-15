import 'package:devpath_web/src/features/community/presentation/qna_detail_page.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('상세: 제목·본문 렌더(목)', (tester) async {
    // P4f-A: QnaDetailPage가 context.dpColors(테마 확장)을 쓰므로 theme 필수.
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: DpTheme.light(),
          home: const QnaDetailPage(postId: 'q1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('async'), findsWidgets); // 목 제목/본문
  });
}
