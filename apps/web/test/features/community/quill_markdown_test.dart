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
}
