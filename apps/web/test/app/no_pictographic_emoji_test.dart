import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 번들 폰트(Pretendard·D2Coding)에 없는 **기본 이모지 표현 문자**를 UI 문자열에 두면
/// 엔진이 Noto Color Emoji 를 받으러 나가고, 그 다운로드가 차단되면 재시도 금지
/// 목록에 들어가지 않아 **레이아웃마다 다시 나간다**. `browser-ux` 러너에서는
/// networkidle 이 영원히 오지 않아 라우트가 정착하지 못한다.
///
/// 실측(S3-P5 CI 36649266533, `browser-ux`): `/community/1` 한 화면에서 외부 요청
/// **2651건** — notosanskr 3청크 × 438·438·437 회와 notocoloremoji 2청크 × 437·434 회.
/// 반복 횟수가 거의 같아 원인 하나가 한 라운드에 다섯 청크를 부른 것이다.
///
/// DESIGN.md §4 가 이미 「와이어프레임의 이모지는 전부 Material Symbols 로 교체」를
/// 규칙으로 두고 있고 시안에도 이모지가 없다. 이 테스트가 그 규칙을 게이트로 만든다.
///
/// **대상 선정 기준 = `Emoji_Presentation=Yes`**(기본 표현이 이모지인 문자)다.
/// 보충 평면의 픽토그래프 전체와, BMP 에서 기본 표현이 이모지인 문자들만 막는다.
/// `✓`(U+2713)·`★`(U+2605)·`●`(U+25CF)·`☀`(U+2600) 같은 **텍스트 표현** 기호는 제외한다 —
/// Pretendard 에 있어 폴백을 부르지 않는다(그 기호를 쓰는 `/dashboard`·`/community` 는
/// 실측에서 라우트당 고정 요청 2건만 냈다). 「U+2600–U+27BF 를 통째로」는 안 된다:
/// 그러면 이 레포가 실제로 쓰는 `✓ 완료`·`✓ 해결됨` 이 오탐이 된다.
final RegExp emojiPresentation = RegExp(
  '['
  // 보충 평면: 마작·카드·둘러싸인 문자·이모티콘·교통·보충 픽토그래프 등 전부.
  // 지역 표시자(U+1F1E6–U+1F1FF = 국기)도 이 안에 있다.
  r'\u{1F000}-\u{1FAFF}'
  // 레거시 컴퓨팅 기호.
  r'\u{1FB00}-\u{1FBFF}'
  // 이모지 변형 선택자 — 앞 문자를 이모지로 그리게 만든다.
  r'\u{FE0F}'
  // BMP 에서 기본 표현이 이모지인 문자들(Emoji_Presentation=Yes).
  r'\u{231A}-\u{231B}\u{23E9}-\u{23EC}\u{23F0}\u{23F3}'
  r'\u{25FD}-\u{25FE}\u{2614}-\u{2615}\u{2648}-\u{2653}\u{267F}\u{2693}'
  r'\u{26A1}\u{26AA}-\u{26AB}\u{26BD}-\u{26BE}\u{26C4}-\u{26C5}\u{26CE}'
  r'\u{26D4}\u{26EA}\u{26F2}-\u{26F3}\u{26F5}\u{26FA}\u{26FD}'
  r'\u{2705}\u{270A}-\u{270B}\u{2728}\u{274C}\u{274E}'
  r'\u{2753}-\u{2755}\u{2757}\u{2795}-\u{2797}\u{27B0}\u{27BF}'
  r'\u{2B1B}-\u{2B1C}\u{2B50}\u{2B55}'
  ']',
  unicode: true,
);

/// 한 줄에서 주석을 지운 나머지. 렌더되는 것은 주석이 아니다.
///
/// 줄 전체 주석만 거르면 안 된다 — 꼬리 주석(`foo(); // 이모지 함정 설명`)이 문자열로
/// 오탐된다. 반대로 `//` 를 무조건 자르면 `'https://…'` 같은 문자열 리터럴에서 잘려
/// 그 뒤의 이모지를 놓친다. 그래서 인용 상태를 따라가며 자른다.
String stripComments(
  String line, {
  required bool inBlock,
  required void Function(bool) setInBlock,
}) {
  final out = StringBuffer();
  String? quote;
  var i = 0;
  var block = inBlock;
  while (i < line.length) {
    final ch = line[i];
    if (block) {
      if (ch == '*' && i + 1 < line.length && line[i + 1] == '/') {
        block = false;
        i += 2;
        continue;
      }
      i += 1;
      continue;
    }
    if (quote != null) {
      out.write(ch);
      if (ch == r'\') {
        if (i + 1 < line.length) out.write(line[i + 1]);
        i += 2;
        continue;
      }
      if (ch == quote) quote = null;
      i += 1;
      continue;
    }
    if (ch == "'" || ch == '"') {
      quote = ch;
      out.write(ch);
      i += 1;
      continue;
    }
    if (ch == '/' && i + 1 < line.length && line[i + 1] == '/') break;
    if (ch == '/' && i + 1 < line.length && line[i + 1] == '*') {
      block = true;
      i += 2;
      continue;
    }
    out.write(ch);
    i += 1;
  }
  setInBlock(block);
  return out.toString();
}

void main() {
  // 이 레포가 실제로 쓰는 텍스트 표현 기호와, 막아야 하는 이모지를 같은 매처로
  // 갈라 둔다. 범위를 넓히거나 좁힐 때 이 테스트가 먼저 말해 준다.
  test('매처는 기본 이모지 표현만 잡고 텍스트 기호는 통과시킨다', () {
    for (final blocked in const [
      '\u{1F916}', // 로봇
      '\u{1F4DA}', // 책
      '\u{1F4A1}', // 전구
      '\u{1F1F0}\u{1F1F7}', // 국기(지역 표시자 쌍)
      '\u{2705}', // 굵은 흰 체크 — 텍스트 기호 ✓ 와 다르다
      '\u{274C}', // 곱셈 기호
      '\u{2B50}', // 별 — 텍스트 기호 ★ 와 다르다
      '\u{2728}', // 반짝임
      '\u{26A1}', // 고전압
      '\u{2B1B}', // 큰 검은 사각형
      '\u{FE0F}', // 이모지 변형 선택자
    ]) {
      expect(
        emojiPresentation.hasMatch(blocked),
        isTrue,
        reason:
            'must be blocked: ${blocked.runes.map((r) => r.toRadixString(16))}',
      );
    }
    for (final allowed in const [
      '\u{2713}', // ✓ 완료 — 이 레포가 쓴다
      '\u{2605}', // ★ 주석 강조
      '\u{25CF}', // ● 다음
      '\u{2600}', // ☀ 텍스트 표현
      '가나다ABC123·—…',
    ]) {
      expect(
        emojiPresentation.hasMatch(allowed),
        isFalse,
        reason:
            'must be allowed: ${allowed.runes.map((r) => r.toRadixString(16))}',
      );
    }
  });

  test('주석 제거는 꼬리 주석을 지우고 문자열 안의 // 는 남긴다', () {
    var block = false;
    String strip(String line) =>
        stripComments(line, inBlock: block, setInBlock: (v) => block = v);

    expect(strip("foo(); // \u{1F916} 설명"), "foo(); ");
    expect(
      strip("const u = 'https://x/\u{1F916}';"),
      "const u = 'https://x/\u{1F916}';",
    );
    expect(strip('/// \u{1F916} 문서 주석'), '');
    expect(
      strip(r"const s = 'it\'s // not a comment';"),
      r"const s = 'it\'s // not a comment';",
    );
    // 블록 주석은 줄을 넘어 이어진다.
    expect(strip('a /* \u{1F916}'), 'a ');
    expect(strip('still \u{1F916} inside'), '');
    expect(strip('*/ b'), ' b');
  });

  test('렌더되는 문자열에 번들 밖 이모지가 없다', () {
    final roots = <String>[
      'lib',
      '../admin/lib',
      '../../packages/dp_design/lib',
      '../../packages/dp_core/lib',
    ];
    final offenders = <String>[];
    var filesScanned = 0;

    for (final root in roots) {
      final dir = Directory(root);
      // **없으면 조용히 넘어가지 않는다.** 예전 판은 상대 경로 넷이 모두 빗나가면
      // 아무것도 스캔하지 않고 통과했다 — 게이트가 소리 없이 죽는 모양이다.
      expect(
        dir.existsSync(),
        isTrue,
        reason: '$root 이 없다. 이 테스트는 apps/web 을 작업 디렉터리로 가정한다',
      );
      for (final entity in dir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        filesScanned += 1;
        var block = false;
        final lines = entity.readAsStringSync().split('\n');
        for (var i = 0; i < lines.length; i++) {
          final code = stripComments(
            lines[i],
            inBlock: block,
            setInBlock: (v) => block = v,
          );
          if (emojiPresentation.hasMatch(code)) {
            offenders.add('${entity.path}:${i + 1}  ${code.trim()}');
          }
        }
      }
    }

    expect(filesScanned, greaterThan(100), reason: '스캔한 파일이 없으면 가드가 죽은 것이다');
    expect(
      offenders,
      isEmpty,
      reason:
          '기본 표현이 이모지인 문자는 Noto Color Emoji 폴백을 부르고, 차단되면 '
          '레이아웃마다 재시도해 browser-ux 의 networkidle 이 오지 않는다. '
          'Material Symbols(DpIcons)로 바꾸거나 지운다 — DESIGN.md §4.\n'
          '${offenders.join('\n')}',
    );
  });
}
