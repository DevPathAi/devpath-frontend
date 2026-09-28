import 'package:flutter/material.dart';

import '../theme/dp_spacing.dart';
import 'dp_window_class.dart';

/// 본문 2열 배치(시안 `.cols`) — 주 내용 2fr, 사이드 1fr, 간격 24.
///
/// 좁은 폭에서는 [main] → [side] 순서로 한 열이 된다.
/// 2열 경계는 **840**([DpWindowClass.expanded] 의 시작)이다. 시안의 컨테이너
/// 질의는 720 이지만(`@container (max-width:720px)`) 이 위젯은 840 을 쓴다 —
/// 시안의 그 한 규칙이 `.cols`(2:1 분할)와 `.login`(1.1:0.9 대등 분할)을 함께
/// 묶고 있고, 2:1 에서는 720 에서 사이드가 약 220px 로 눌려 패널 제목조차
/// 줄바꿈한다. 시안 갤러리는 1440·390 두 폭만 보여 주므로 720~839 는 시각
/// 검토된 적이 없다 — 검토되지 않은 구간에서는 더 보수적인 경계를 택했다.
/// (S3-P5 사용자 결정 2026-09-28. 근거는 DESIGN.md §5.)
///
/// 폭·좌우 패딩은 셸(`DpWebShell`)이 준다 — 이 위젯은 그 안에서 나누기만 한다.
class DpCols extends StatelessWidget {
  const DpCols({
    super.key,
    required this.main,
    required this.side,
    this.stretch = false,
  });

  final Widget main;
  final Widget side;

  /// 부모 높이를 채운다. 내부에 자체 스크롤 위젯(`ListView` 등)을 둔 화면이
  /// 쓴다 — 기본값(false)은 시안 `align-items:start` 그대로다.
  final bool stretch;

  @override
  Widget build(BuildContext context) {
    final twoColumn = switch (context.windowClass) {
      DpWindowClass.expanded || DpWindowClass.large => true,
      DpWindowClass.compact || DpWindowClass.medium => false,
    };

    if (!twoColumn) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: stretch ? MainAxisSize.max : MainAxisSize.min,
        children: [
          stretch ? Expanded(child: main) : main,
          const SizedBox(height: DpSpacing.xl),
          side,
        ],
      );
    }

    return Row(
      // 시안 `align-items:start` — 사이드가 주 내용 높이만큼 늘어나지 않는다.
      // `stretch` 면 둘 다 부모 높이를 채운다(내부 스크롤 위젯을 둔 화면).
      crossAxisAlignment: stretch
          ? CrossAxisAlignment.stretch
          : CrossAxisAlignment.start,
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
