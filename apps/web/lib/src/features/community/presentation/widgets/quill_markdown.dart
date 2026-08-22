import 'package:flutter_quill/flutter_quill.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:markdown_quill/markdown_quill.dart';

/// Quill 문서(Delta)를 마크다운 문자열로 변환한다.
///
/// 저장 계약은 기존과 동일한 `bodyMd`(마크다운)이므로, 에디터의 Delta 는
/// 메모리 전용 표현이고 게시 직전 이 함수로 마크다운을 산출한다.
/// 툴바는 마크다운으로 무손실 표현 가능한 서식만 노출한다(`DpRichEditor`).
String quillToMarkdown(QuillController controller) => DeltaToMarkdown(
  // 기본 핸들러(escapeSpecialCharacters)는 평문의 구두점까지 전부 백슬래시
  // 이스케이프해 `bodyMd`를 오염시킨다("안녕하세요." → "안녕하세요\."). 저장된
  // 마크다운을 평문으로 소비하는 곳(커뮤니티 피드 excerpt 등)에 백슬래시가 그대로
  // 드러나므로, 서식이 실제로 붙은 텍스트만 이스케이프하는 완화 핸들러를 쓴다.
  customContentHandler: DeltaToMarkdown.escapeSpecialCharactersRelaxed,
).convert(controller.document.toDelta());

/// 마크다운 문자열을 Quill 문서로 되돌린다 — 편집 모드가 기존 본문을 에디터에 채울 때 쓴다.
///
/// 저장 계약이 마크다운이므로 편집은 반드시 이 방향을 거친다. 툴바가 마크다운으로 무손실
/// 표현 가능한 서식만 노출하므로(`DpRichEditor`) 왕복이 대체로 안정적이지만, **완전한
/// 무손실을 보장하지는 않는다** — 이용자가 외부에서 붙여넣은 표·각주 같은 확장 문법은
/// 평문으로 강등될 수 있다.
///
/// 빈 문자열이면 빈 문서를 낸다. `Document.fromDelta` 는 개행으로 끝나지 않는 Delta 를
/// 거부하므로 그 경우를 따로 처리한다.
Document markdownToQuillDocument(String markdown) {
  if (markdown.trim().isEmpty) return Document();
  final delta = MarkdownToDelta(
    markdownDocument: md.Document(),
  ).convert(markdown);
  if (delta.isEmpty) return Document();
  return Document.fromDelta(delta);
}
