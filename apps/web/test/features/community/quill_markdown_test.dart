import 'package:devpath_web/src/features/community/presentation/widgets/quill_markdown.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';

QuillController _controllerOf(void Function(Document d) build) {
  final doc = Document();
  build(doc);
  return QuillController(
    document: doc,
    selection: const TextSelection.collapsed(offset: 0),
  );
}

void main() {
  test('굵게 → 마크다운 강조', () {
    final c = _controllerOf((d) {
      d.insert(0, '굵게');
      d.format(0, 2, Attribute.bold);
    });
    addTearDown(c.dispose);
    expect(quillToMarkdown(c).trim(), '**굵게**');
  });

  test('제목(H1) → 마크다운 헤딩', () {
    final c = _controllerOf((d) {
      d.insert(0, '제목');
      d.format(2, 1, Attribute.h1);
    });
    addTearDown(c.dispose);
    expect(quillToMarkdown(c).trim(), '# 제목');
  });

  test('불릿 목록 → 마크다운 리스트', () {
    final c = _controllerOf((d) {
      d.insert(0, '항목');
      d.format(2, 1, Attribute.ul);
    });
    addTearDown(c.dispose);
    expect(quillToMarkdown(c).trim(), '- 항목');
  });

  test('인용 → 마크다운 blockquote', () {
    final c = _controllerOf((d) {
      d.insert(0, '인용');
      d.format(2, 1, Attribute.blockQuote);
    });
    addTearDown(c.dispose);
    expect(quillToMarkdown(c).trim(), '> 인용');
  });

  test('인라인 코드 → 백틱', () {
    final c = _controllerOf((d) {
      d.insert(0, 'code');
      d.format(0, 4, Attribute.inlineCode);
    });
    addTearDown(c.dispose);
    expect(quillToMarkdown(c).trim(), '`code`');
  });

  test('링크 → 마크다운 링크', () {
    final c = _controllerOf((d) {
      d.insert(0, 'DevPath');
      d.format(0, 7, LinkAttribute('https://leva.ai.kr'));
    });
    addTearDown(c.dispose);
    expect(quillToMarkdown(c).trim(), '[DevPath](https://leva.ai.kr)');
  });

  test('취소선 변환 여부 고정 — showStrikeThrough 결정 근거', () {
    final c = _controllerOf((d) {
      d.insert(0, '취소선');
      d.format(0, 3, Attribute.strikeThrough);
    });
    addTearDown(c.dispose);
    // 관찰값이 '~~취소선~~' 이면 툴바 ON, '취소선'(서식 소실)이면 OFF.
    expect(quillToMarkdown(c).trim(), '~~취소선~~');
  });

  test('한글 평문은 그대로 보존된다', () {
    final c = _controllerOf((d) => d.insert(0, '한글 본문입니다'));
    addTearDown(c.dispose);
    expect(quillToMarkdown(c).trim(), '한글 본문입니다');
  });

  test('빈 문서는 공백만 남는다', () {
    final c = QuillController.basic();
    addTearDown(c.dispose);
    expect(quillToMarkdown(c).trim(), isEmpty);
  });

  test('평문 구두점은 이스케이프되지 않는다 — 문장부호', () {
    final c = _controllerOf(
      (d) => d.insert(0, '리액트에서 useEffect가 두 번 실행됩니다. 왜 그럴까요?'),
    );
    addTearDown(c.dispose);
    expect(quillToMarkdown(c).trim(), '리액트에서 useEffect가 두 번 실행됩니다. 왜 그럴까요?');
  });

  test('평문 구두점은 이스케이프되지 않는다 — 특수기호', () {
    final c = _controllerOf((d) => d.insert(0, 'C# 과 C++ 차이'));
    addTearDown(c.dispose);
    expect(quillToMarkdown(c).trim(), 'C# 과 C++ 차이');
  });

  test('평문 구두점은 이스케이프되지 않는다 — 괄호/느낌표', () {
    final c = _controllerOf((d) => d.insert(0, '안녕하세요. 질문 (있습니다)!'));
    addTearDown(c.dispose);
    expect(quillToMarkdown(c).trim(), '안녕하세요. 질문 (있습니다)!');
  });

  test('서식이 붙은 텍스트의 특수문자는 여전히 이스케이프된다', () {
    final c = _controllerOf((d) {
      d.insert(0, 'a*b');
      d.format(0, 3, Attribute.bold);
    });
    addTearDown(c.dispose);
    expect(quillToMarkdown(c).trim(), '**a\\*b**');
  });

  test('코드블록 → 마크다운 펜스', () {
    final c = _controllerOf((d) {
      d.insert(0, 'const x = 1;');
      d.format(12, 1, Attribute.codeBlock);
    });
    addTearDown(c.dispose);
    expect(quillToMarkdown(c).trim(), '```\nconst x = 1;\n```');
  });
}
