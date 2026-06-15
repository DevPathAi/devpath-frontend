import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/run_controller.dart';
import '../state/run_state.dart';
import 'monaco_editor_view.dart';
import 'sandbox_layout.dart';

const _kInitialCode = 'void main() {\n  print(\'hello devpath\');\n}\n';

class SandboxPage extends ConsumerStatefulWidget {
  const SandboxPage({super.key});

  @override
  ConsumerState<SandboxPage> createState() => _SandboxPageState();
}

class _SandboxPageState extends ConsumerState<SandboxPage> {
  String _code = _kInitialCode;
  // F5-b: 에디터 가시화 시 Monaco 재레이아웃 트리거용 핸들.
  final GlobalKey<MonacoEditorViewState> _editorKey =
      GlobalKey<MonacoEditorViewState>();

  @override
  Widget build(BuildContext context) {
    final run = ref.watch(runControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sandbox'),
        actions: [
          FilledButton(
            onPressed: run is RunRunning
                ? null
                : () => ref.read(runControllerProvider.notifier).run(_code),
            child: const Text('실행'),
          ),
          const SizedBox(width: DpSpacing.md),
        ],
      ),
      body: SandboxLayout(
        // F5-b: <1024 세그먼트 탭에서 에디터 재가시화 시 layout() 보정.
        onEditorVisible: () => _editorKey.currentState?.layout(),
        editor: MonacoEditorView(
          key: _editorKey,
          initialCode: _kInitialCode,
          onChanged: (v) => _code = v,
        ),
        log: _LogPane(run: run),
        review: const _ReviewPlaceholder(),
      ),
    );
  }
}

/// 실행 로그(codeLogBg). SANDBOX_UNAVAILABLE이면 전용 안내(편집은 유지).
class _LogPane extends StatelessWidget {
  const _LogPane({required this.run});
  final RunState run;

  @override
  Widget build(BuildContext context) {
    if (run is RunUnavailable) return const DpSandboxUnavailable();
    final logs = switch (run) {
      RunRunning(:final logs) => logs,
      RunDone(:final logs) => logs,
      _ => const <String>[],
    };
    return Container(
      color: context.dpColors.codeLogBg,
      padding: const EdgeInsets.all(DpSpacing.md),
      child: logs.isEmpty
          ? Text(
              '실행 결과가 여기에 표시됩니다.',
              style: DpTypography.code.copyWith(
                color: context.dpColors.codeText,
              ),
            )
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final l in logs)
                    Text(
                      l,
                      style: DpTypography.code.copyWith(
                        color: context.dpColors.codeText,
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

/// AI 리뷰 칸 — P4d에서 REV-001로 채움.
class _ReviewPlaceholder extends StatelessWidget {
  const _ReviewPlaceholder();

  @override
  Widget build(BuildContext context) => const DpEmpty(
    icon: DpIcons.content,
    title: 'AI 리뷰',
    message: '코드를 실행하면 리뷰가 제공됩니다. (P4d)',
  );
}
