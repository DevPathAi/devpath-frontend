import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 번들 폰트(Pretendard·D2Coding)에 없는 **픽토그래픽 이모지**를 UI 문자열에 두면
/// 엔진이 Noto Color Emoji 를 받으러 나가고, 그 다운로드가 차단되면 재시도 금지
/// 목록에 들어가지 않아 **레이아웃마다 다시 나간다**. `browser-ux` 러너에서는
/// networkidle 이 영원히 오지 않아 라우트가 정착하지 못한다.
///
/// 실측(S3-P5 CI 36649266533, `browser-ux`): `/community/1` 한 화면에서 외부 요청
/// **2651건** — notosanskr 3청크 × 438·437·435 회와 notocoloremoji 2청크 × 437·434 회.
/// 반복 횟수가 거의 같아 원인 하나가 한 라운드에 다섯 청크를 부른 것이다.
///
/// DESIGN.md §4 가 이미 「와이어프레임의 이모지는 전부 Material Symbols 로 교체」를
/// 규칙으로 두고 있고 시안에도 픽토그래픽 이모지가 없다. 이 테스트가 그 규칙을
/// 게이트로 만든다.
///
/// 대상은 **보충 평면의 픽토그래프(U+1F300–U+1FAFF)와 이모지 변형 선택자(U+FE0F)** 뿐이다.
/// `✓`(U+2713)·`★`(U+2605)·`●`(U+25CF) 는 Pretendard 에 있어 폴백을 부르지 않는다
/// (그 기호를 쓰는 /dashboard·/community 는 실측에서 라우트당 고정 요청만 냈다).
void main() {
  test('렌더되는 문자열에 번들 밖 픽토그래픽 이모지가 없다', () {
    final pictographic = RegExp(
      r'[\u{1F300}-\u{1FAFF}\u{FE0F}]',
      unicode: true,
    );
    final roots = <String>[
      'lib',
      '../../packages/dp_design/lib',
      '../admin/lib',
    ];
    final offenders = <String>[];

    for (final root in roots) {
      final dir = Directory(root);
      if (!dir.existsSync()) continue;
      for (final entity in dir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final lines = entity.readAsStringSync().split('\n');
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          // 주석은 렌더되지 않는다. 이 레포는 주석에 ★ 를 즐겨 쓰고, 이모지로
          // 함정을 설명하는 주석도 있다(dp_icons.dart 가 바로 그 규칙의 출처다).
          if (line.trimLeft().startsWith('//')) continue;
          if (pictographic.hasMatch(line)) {
            offenders.add('${entity.path}:${i + 1}  ${line.trim()}');
          }
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          '픽토그래픽 이모지는 Noto Color Emoji 폴백을 부르고, 차단되면 레이아웃마다 '
          '재시도해 browser-ux 의 networkidle 이 오지 않는다. Material Symbols'
          '(DpIcons)로 바꾸거나 지운다 — DESIGN.md §4.\n${offenders.join('\n')}',
    );
  });
}
