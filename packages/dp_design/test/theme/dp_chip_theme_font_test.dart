import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Material 은 `chipTheme.labelStyle` 을 기본값과 **병합하지 않고 대체**한다
/// (`chip.dart`: `chipTheme.labelStyle ?? chipDefaults.labelStyle!`). 기본값이
/// `textTheme.labelLarge` 라 앱 폰트는 거기에만 들어 있다 — 테마가 labelStyle 을
/// 주는 순간 칩만 앱 폰트를 잃고 엔진 기본 패밀리로 그려진다.
///
/// 웹에서는 그 패밀리가 번들에 없어 실제 피해가 두 겹이다.
/// ① 칩 글자가 Pretendard 가 아니다(외부 네트워크가 막힌 환경에서는 아예 안 보인다).
/// ② 칩 라벨이 넘칠 때 Material 이 쓰는 `TextOverflow.fade` 는 사라짐 폭을 재려고
///    `'…'` 만 담은 문단을 따로 만든다(`rendering/paragraph.dart`). 그 글자가
///    등록된 패밀리에 없으므로 엔진이 Noto fallback 다운로드를 걸고, 실패한
///    다운로드는 「받았다」로도 「가진 폰트가 없다」로도 기록되지 않아 레이아웃마다
///    다시 시도된다 — `/content` 390px·텍스트 배율 200% 에서 수백 건의 외부 요청이
///    나고 `networkidle` 이 영영 오지 않았다(2026-09-26 실측).
void main() {
  for (final (name, theme) in [
    ('light', DpTheme.light()),
    ('dark', DpTheme.dark()),
  ]) {
    test('DpTheme.$name 의 chipTheme.labelStyle 은 앱 폰트를 지닌다', () {
      expect(theme.chipTheme.labelStyle?.fontFamily, DpTypography.family);
    });
  }

  testWidgets('Chip 라벨은 앱 폰트로 해석된다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: DpTheme.light(),
        home: const Scaffold(
          body: Center(child: Chip(label: Text('async-await'))),
        ),
      ),
    );

    final richText = tester.widget<RichText>(
      find.descendant(of: find.byType(Chip), matching: find.byType(RichText)),
    );
    expect((richText.text as TextSpan).style?.fontFamily, DpTypography.family);
  });
}
