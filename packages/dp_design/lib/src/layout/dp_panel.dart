import 'package:flutter/material.dart';

import '../theme/dp_colors.dart';
import '../theme/dp_spacing.dart';

/// 웹 문법 패널(시안 `.panel`) — 표면 + 1px 테두리 + 반경 8 컨테이너.
///
/// 웹 화면에서 Material `Card` 를 대신한다. 그림자를 쓰지 않는다 —
/// 시안의 면 구분은 테두리 한 겹뿐이다.
///
/// [padding] 기본값이 0 인 이유: 이 패널의 주 내용물인 표·목록은 행마다
/// 자기 패딩을 갖고 구분선이 패널 폭 전체를 가로질러야 한다. 바깥에서
/// 패딩을 주면 구분선이 안쪽으로 밀려 시안과 달라진다.
class DpPanel extends StatelessWidget {
  const DpPanel({super.key, this.title, required this.child, this.padding});

  /// 있으면 하단 구분선을 가진 제목행을 그린다.
  final Widget? title;
  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final c = context.dpColors;
    final text = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(DpRadius.card),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null)
            Container(
              key: const ValueKey('dp-panel-title'),
              padding: const EdgeInsets.symmetric(
                vertical: DpSpacing.md,
                horizontal: DpSpacing.lg,
              ),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: c.border)),
              ),
              child: Semantics(
                header: true,
                child: DefaultTextStyle.merge(
                  style: text.titleSmall?.copyWith(color: c.textPrimary),
                  child: title!,
                ),
              ),
            ),
          Padding(padding: padding ?? EdgeInsets.zero, child: child),
        ],
      ),
    );
  }
}
