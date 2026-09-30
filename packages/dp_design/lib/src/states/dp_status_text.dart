import 'package:flutter/material.dart';

import '../theme/dp_colors.dart';

/// 상태 문구의 의미 축(시안 `.st ok/no/now`).
enum DpStatusTone {
  /// 끝난 것 — `.st.ok`
  done,

  /// 아직인 것 — `.st.no`
  idle,

  /// 지금 할 것 — `.st.now`
  current,
}

/// 표·목록의 상태 칼럼(시안 `.st`). 12px·600·줄바꿈 없음.
///
/// 색만으로 의미를 전달하지 않도록 호출부가 기호를 함께 넣는다
/// (`'✓ 완료'`·`'● 다음'`) — 이 위젯은 기호를 만들지 않는다.
class DpStatusText extends StatelessWidget {
  const DpStatusText({super.key, required this.text, required this.tone});

  final String text;
  final DpStatusTone tone;

  @override
  Widget build(BuildContext context) {
    final c = context.dpColors;
    final color = switch (tone) {
      DpStatusTone.done => c.success,
      DpStatusTone.idle => c.textSecondary,
      DpStatusTone.current => c.primaryTextStrong,
    };

    final base = Theme.of(context).textTheme.labelMedium;
    return Text(
      text,
      softWrap: false,
      overflow: TextOverflow.clip,
      style: base?.copyWith(color: color),
    );
  }
}
