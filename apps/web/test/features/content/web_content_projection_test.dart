import 'package:devpath_web/src/features/content/presentation/content_page.dart';
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// `WebContentProjection` 은 ET13 시각 증거의 결정적 투영이기도 하다 —
/// 여기서 재는 폭·태그 문법이 그 기준선의 모양을 정한다.
Widget _host(LearningContent content) => MaterialApp(
  theme: DpTheme.light(),
  home: Scaffold(
    body: SingleChildScrollView(
      child: WebContentProjection(
        content: content,
        // 광고 슬롯은 provider 를 요구한다 — 이 테스트의 대상이 아니다.
        adSlot: const SizedBox.shrink(),
      ),
    ),
  ),
);

LearningContent _content({List<String> tags = const ['비동기', 'Stream']}) =>
    LearningContent.fromJson({
      'id': 5,
      'slug': 'async-basics',
      'title': '비동기 기초',
      'track': 'BACKEND',
      'markdown': '본문 문단',
      'estimatedMinutes': 12,
      'conceptTags': tags,
      'progress': {'scrollPct': 0.4, 'dwellSec': 30, 'completed': false},
    });

void main() {
  testWidgets('WebContentProjection: 본문 폭이 readableMaxWidth(760) 다', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host(_content()));

    final box = tester.widget<ConstrainedBox>(
      find
          .descendant(
            of: find.byType(WebContentProjection),
            matching: find.byType(ConstrainedBox),
          )
          .first,
    );
    expect(box.constraints.maxWidth, 760);
  });

  testWidgets('WebContentProjection: 개념 태그를 DpTag 로 그린다', (tester) async {
    tester.view.physicalSize = const Size(1280, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host(_content()));

    // Material `Chip` 은 P2 에서 폰트 폭주의 원인이었다
    // (`ChipThemeData.labelStyle` 이 앱 폰트를 대체한다).
    expect(find.byType(DpTag), findsNWidgets(2));
    expect(find.byType(Chip), findsNothing);
  });

  testWidgets('WebContentProjection: 진행률 바는 본문에 없다 — 사이드 패널이 맡는다', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host(_content()));

    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.textContaining('% 진행'), findsNothing);
    // 제목·메타는 그대로 본문에 남는다.
    expect(find.text('비동기 기초'), findsOneWidget);
    expect(find.textContaining('12분'), findsOneWidget);
  });
}
