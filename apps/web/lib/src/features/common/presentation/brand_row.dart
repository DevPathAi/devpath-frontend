import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';

/// 셸 밖 화면(로그인·동의·진단·베타)의 상단 브랜드 행.
/// 이 화면들엔 레일이 없어 제품 정체성을 보여줄 자리가 여기뿐이다.
Widget brandRow(BuildContext context, {List<Widget> actions = const []}) {
  final c = context.dpColors;
  final text = Theme.of(context).textTheme;
  return Padding(
    key: const ValueKey('brand-row'),
    padding: const EdgeInsets.fromLTRB(
      DpSpacing.lg,
      DpSpacing.lg,
      DpSpacing.lg,
      0,
    ),
    child: Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: c.primary,
            borderRadius: BorderRadius.circular(DpRadius.button),
          ),
        ),
        const SizedBox(width: DpSpacing.sm),
        // Flexible로 감싼다 — Spacer(Expanded)와 같은 Row의 non-flex 자식은
        // 무한 주축 제약으로 측정되어 ellipsis가 발동하지 않고 오버플로한다.
        Flexible(
          child: Text(
            'DevPath',
            overflow: TextOverflow.ellipsis,
            style: text.titleSmall?.copyWith(color: c.textPrimary),
          ),
        ),
        const Spacer(),
        ...actions,
      ],
    ),
  );
}
