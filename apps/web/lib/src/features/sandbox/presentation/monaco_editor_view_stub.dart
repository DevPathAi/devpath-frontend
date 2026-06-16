import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';

import 'monaco_editor_view.dart' show MonacoHandle;

/// 비웹/테스트: 읽기전용 코드 미리보기(Monaco 미로드). web과 동일 핸들 인터페이스.
MonacoHandle createMonacoHandle({
  required String initialCode,
  ValueChanged<String>? onChanged,
  VoidCallback? onEscape,
}) => _StubHandle(initialCode);

class _StubHandle implements MonacoHandle {
  _StubHandle(this._code);
  final String _code;

  @override
  Widget get view => Container(
    color: const Color(0xFF1E1E1E), // DESIGN codeEditorBg
    padding: const EdgeInsets.all(DpSpacing.md),
    child: SingleChildScrollView(
      child: Text(
        _code,
        style: DpTypography.code.copyWith(color: const Color(0xFFD4D4D4)),
      ),
    ),
  );

  @override
  void layout() {} // no-op (stub)

  @override
  void dispose() {} // no-op (stub)
}
