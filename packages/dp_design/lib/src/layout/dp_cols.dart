import 'package:flutter/material.dart';

import '../theme/dp_spacing.dart';
import 'dp_window_class.dart';

/// 본문 2열 배치(시안 `.cols`) — 주 내용 2fr, 사이드 1fr, 간격 24.
///
/// 좁은 폭에서는 [main] → [side] 순서로 한 열이 된다(시안
/// `@container (max-width:720px){.cols{grid-template-columns:minmax(0,1fr)}}`).
/// 경계를 [DpWindowClass.expanded](1240) 에 두는 이유: 셸 본문은 최대 1120 이고
/// 사이드가 1fr 이므로 840~1239 에서 사이드가 약 270px 까지 눌린다. 그 폭에서는
/// 표가 이미 자체 가로 스크롤로 들어가 2열이 읽히지 않는다.
///
/// 폭·좌우 패딩은 셸(`DpWebShell`)이 준다 — 이 위젯은 그 안에서 나누기만 한다.
class DpCols extends StatelessWidget {
  const DpCols({super.key, required this.main, required this.side});

  final Widget main;
  final Widget side;

  @override
  Widget build(BuildContext context) {
    final twoColumn = switch (context.windowClass) {
      DpWindowClass.expanded || DpWindowClass.large => true,
      DpWindowClass.compact || DpWindowClass.medium => false,
    };

    if (!twoColumn) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          main,
          const SizedBox(height: DpSpacing.xl),
          side,
        ],
      );
    }

    return Row(
      // 시안 `align-items:start` — 사이드가 주 내용 높이만큼 늘어나지 않는다.
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 2, child: main),
        const SizedBox(width: DpSpacing.xl),
        Expanded(child: side),
      ],
    );
  }
}

/// 사이드 칼럼의 세로 스택(시안 `.side{display:flex;flex-direction:column;gap:16px}`).
class DpSide extends StatelessWidget {
  const DpSide({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 0; i < children.length; i++) ...[
        if (i > 0) const SizedBox(height: DpSpacing.lg),
        children[i],
      ],
    ],
  );
}
