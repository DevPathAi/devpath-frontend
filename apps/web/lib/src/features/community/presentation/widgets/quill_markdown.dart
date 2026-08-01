import 'package:flutter_quill/flutter_quill.dart';
import 'package:markdown_quill/markdown_quill.dart';

/// Quill 문서(Delta)를 마크다운 문자열로 변환한다.
///
/// 저장 계약은 기존과 동일한 `bodyMd`(마크다운)이므로, 에디터의 Delta 는
/// 메모리 전용 표현이고 게시 직전 이 함수로 마크다운을 산출한다.
/// 툴바는 마크다운으로 무손실 표현 가능한 서식만 노출한다(`DpRichEditor`).
String quillToMarkdown(QuillController controller) =>
    DeltaToMarkdown().convert(controller.document.toDelta());
