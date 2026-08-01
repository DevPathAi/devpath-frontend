import 'package:flutter_quill/flutter_quill.dart';
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
