import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';

/// DD5/§9.3: ≥1240 3페인 · 1024–1239 2페인(에디터|리뷰)+로그 접이 · <1024 세그먼트 탭.
class SandboxLayout extends StatefulWidget {
  const SandboxLayout({
    super.key,
    required this.editor,
    required this.log,
    required this.review,
    this.onEditorVisible,
  });

  final Widget editor;
  final Widget log;
  final Widget review;

  /// F5-b: 에디터 페인이 (재)가시화될 때 호출 — Monaco `editor.layout()` 보정용.
  final VoidCallback? onEditorVisible;

  @override
  State<SandboxLayout> createState() => SandboxLayoutState();
}

class SandboxLayoutState extends State<SandboxLayout> {
  int _tab = 0; // <1024 세그먼트: 0=editor 1=log 2=review
  bool _logOpen = true; // 1024–1239 로그 접이

  void showEditor() => _showPane(0);
  void showLog() => _showPane(1);
  void showReview() => _showPane(2);

  void _showPane(int pane) {
    if (!mounted || _tab == pane) return;
    setState(() => _tab = pane);
    if (pane == 0) widget.onEditorVisible?.call();
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final c = context.dpColors;

    Widget pane(Widget child) => Container(
      decoration: BoxDecoration(border: Border.all(color: c.border)),
      child: child,
    );

    if (w >= 1240) {
      return Row(
        children: [
          Expanded(flex: 5, child: pane(widget.editor)),
          Expanded(flex: 3, child: pane(widget.log)),
          Expanded(flex: 4, child: pane(widget.review)),
        ],
      );
    }

    if (w >= 1024) {
      return Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(flex: 6, child: pane(widget.editor)),
                Expanded(flex: 5, child: pane(widget.review)),
              ],
            ),
          ),
          // 로그 접이
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _logOpen = !_logOpen),
              icon: Icon(_logOpen ? DpIcons.expandMore : DpIcons.expandLess),
              label: Text(_logOpen ? '실행 로그 접기' : '실행 로그 펼치기'),
            ),
          ),
          if (_logOpen) SizedBox(height: 160, child: pane(widget.log)),
        ],
      );
    }

    // <1024: 세그먼트 탭 1페인
    // F5-b 반영: panes[_tab]로 현재 탭만 트리에 넣으면 탭 전환 시 에디터 State(입력)가
    // 폐기되어 코드가 소실된다 → IndexedStack으로 전 페인을 트리에 유지하고 하나만 visible.
    return Column(
      children: [
        // 좌측 정렬 — Column의 기본 crossAxisAlignment(center)로는 세그먼트가
        // 중앙에 놓여 페이지 헤더의 좌측선과 어긋난다(실측 left=255.6 vs 헤더 16).
        // 가로 여백은 헤더와 같은 lg(16)로 맞추고 세로만 sm(8)을 유지한다.
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DpSpacing.lg,
            vertical: DpSpacing.sm,
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('에디터')),
                ButtonSegment(value: 1, label: Text('실행')),
                ButtonSegment(value: 2, label: Text('리뷰')),
              ],
              selected: {_tab},
              onSelectionChanged: (s) => setState(() {
                _tab = s.first;
                // 에디터 가시화 시 Monaco 재레이아웃(숨김 동안 0px였던 레이아웃 보정).
                if (_tab == 0) widget.onEditorVisible?.call();
              }),
            ),
          ),
        ),
        Expanded(
          child: pane(
            IndexedStack(
              index: _tab,
              children: [widget.editor, widget.log, widget.review],
            ),
          ),
        ),
      ],
    );
  }
}
