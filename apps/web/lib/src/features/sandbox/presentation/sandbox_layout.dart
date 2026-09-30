import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';

/// DD5/§9.3: ≥1240 3페인 · 1024–1239 2페인(에디터|리뷰)+로그 접이 · <1024 세그먼트 탭.
///
/// 크롬은 시안 `.ide{border:1px solid;border-radius:8px;overflow:hidden}` +
/// `.ide .pane+.pane{border-left:1px solid}` 다 — 바깥 테두리 한 겹과 페인 사이
/// 구분선. 반응형 거동(3/2/1페인)은 앱 기능이라 그대로 둔다.
class SandboxLayout extends StatefulWidget {
  const SandboxLayout({
    super.key,
    required this.editor,
    required this.log,
    required this.review,
    this.onEditorVisible,
    this.onReviewVisibilityChanged,
  });

  final Widget editor;
  final Widget log;
  final Widget review;

  /// F5-b: 에디터 페인이 (재)가시화될 때 호출 — Monaco `editor.layout()` 보정용.
  final VoidCallback? onEditorVisible;
  final ValueChanged<bool>? onReviewVisibilityChanged;

  @override
  State<SandboxLayout> createState() => SandboxLayoutState();
}

class SandboxLayoutState extends State<SandboxLayout> {
  int _tab = 0; // <1024 세그먼트: 0=editor 1=log 2=review
  bool _logOpen = true; // 1024–1239 로그 접이
  bool _reviewVisible = false;
  bool? _lastReportedReviewVisibility;

  bool get isReviewVisible => _reviewVisible;

  void showEditor() => _showPane(0);
  void showLog() => _showPane(1);
  void showReview() => _showPane(2);

  void _showPane(int pane) {
    if (!mounted || _tab == pane) return;
    setState(() => _tab = pane);
    if (pane == 0) widget.onEditorVisible?.call();
  }

  void _reportReviewVisibility(bool visible) {
    _reviewVisible = visible;
    if (_lastReportedReviewVisibility == visible) return;
    _lastReportedReviewVisibility = visible;
    final callback = widget.onReviewVisibilityChanged;
    if (callback == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _reviewVisible == visible) callback(visible);
    });
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    _reportReviewVisibility(w >= 1024 || _tab == 2);

    if (w >= 1240) {
      return _IdeFrame(
        child: Row(
          children: [
            Expanded(flex: 5, child: widget.editor),
            const _PaneDivider(),
            Expanded(flex: 3, child: widget.log),
            const _PaneDivider(),
            Expanded(flex: 4, child: widget.review),
          ],
        ),
      );
    }

    if (w >= 1024) {
      return Column(
        children: [
          Expanded(
            child: _IdeFrame(
              child: Row(
                children: [
                  Expanded(flex: 6, child: widget.editor),
                  const _PaneDivider(),
                  Expanded(flex: 5, child: widget.review),
                ],
              ),
            ),
          ),
          // 로그 접이 — 1024–1239 전용 기능이므로 유지한다.
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _logOpen = !_logOpen),
              icon: Icon(_logOpen ? DpIcons.expandMore : DpIcons.expandLess),
              label: Text(_logOpen ? '실행 로그 접기' : '실행 로그 펼치기'),
            ),
          ),
          if (_logOpen)
            SizedBox(height: 160, child: _IdeFrame(child: widget.log)),
        ],
      );
    }

    // <1024: 세그먼트 탭 1페인
    // F5-b 반영: panes[_tab]로 현재 탭만 트리에 넣으면 탭 전환 시 에디터 State(입력)가
    // 폐기되어 코드가 소실된다 → IndexedStack으로 전 페인을 트리에 유지하고 하나만 visible.
    return Column(
      children: [
        // 좌우 패딩을 주지 않는다 — 셸이 본문 거터를 주고 `DpPageHeader` 도
        // 이제 스스로 주지 않는다(S3-P4 Task 1). 여기서 또 주면 세그먼트가
        // 헤더보다 더 들여쓰인다.
        Padding(
          padding: const EdgeInsets.symmetric(vertical: DpSpacing.sm),
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
          child: _IdeFrame(
            child: IndexedStack(
              index: _tab,
              children: [widget.editor, widget.log, widget.review],
            ),
          ),
        ),
      ],
    );
  }
}

/// 시안 `.ide` 의 바깥 프레임 — 테두리 한 겹 + 반경 8 + 넘침 자르기.
///
/// 페인마다 `Border.all` 을 두르면 페인 사이가 2px 로 보인다(옛 코드).
class _IdeFrame extends StatelessWidget {
  const _IdeFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.dpColors;
    return Container(
      key: const ValueKey('sandbox-ide-frame'),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(DpRadius.card),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

/// 시안 `.ide .pane+.pane{border-left:1px solid var(--border)}`.
///
/// 키를 가진 `Container` 를 이 위젯으로 한 겹 감싸는 이유: 같은 `ValueKey` 를
/// 단 위젯들을 `Row` 의 **형제**로 두면 `Duplicate keys found` 로 죽는다.
class _PaneDivider extends StatelessWidget {
  const _PaneDivider();

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('sandbox-pane-divider'),
    width: 1,
    color: context.dpColors.border,
  );
}
