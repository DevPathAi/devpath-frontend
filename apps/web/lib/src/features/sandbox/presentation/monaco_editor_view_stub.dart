import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:dp_core/dp_core.dart';

import 'monaco_editor_view.dart' show MonacoHandle;

/// 비웹/테스트: 읽기전용 코드 미리보기(Monaco 미로드). web과 동일 핸들 인터페이스.
MonacoHandle createMonacoHandle({
  required String initialCode,
  required SandboxLanguage language,
  ValueChanged<String>? onChanged,
  VoidCallback? onReady,
  VoidCallback? onEscape,
}) {
  onReady?.call();
  return _StubHandle(initialCode);
}

class _StubHandle implements MonacoHandle {
  _StubHandle(String code) : _code = ValueNotifier(code);
  final ValueNotifier<String> _code;

  @override
  Widget get view => ValueListenableBuilder<String>(
    valueListenable: _code,
    builder: (context, code, _) => Container(
      color: const Color(0xFF1E1E1E), // DESIGN codeEditorBg
      padding: const EdgeInsets.all(DpSpacing.md),
      child: SingleChildScrollView(
        child: Text(
          code,
          style: DpTypography.code.copyWith(color: const Color(0xFFD4D4D4)),
        ),
      ),
    ),
  );

  @override
  void update({required String code, required SandboxLanguage language}) {
    if (_code.value != code) _code.value = code;
  }

  @override
  void layout() {} // no-op (stub)

  @override
  void dispose() => _code.dispose();
}
