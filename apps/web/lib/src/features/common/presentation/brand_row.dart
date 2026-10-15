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
        const DpBrandMark(size: 32),
        const SizedBox(width: DpSpacing.sm),
        // Expanded 하나로 남는 폭을 전부 받는다 — non-flex 자식은 무한 주축 제약으로
        // 측정되어 ellipsis가 발동하지 않고 오버플로한다. Flexible(loose)+Spacer 로
        // 두면 둘이 폭을 반씩 나눠 워드마크가 안 쓴 몫이 액션 뒤에 남는다
        // (운영 1280px 에서 테마 토글이 694px 지점에 떴다, 2026-10-15).
        Expanded(
          child: Text(
            '레바',
            overflow: TextOverflow.ellipsis,
            style: text.titleMedium?.copyWith(
              color: c.textPrimary,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
        ),
        ...actions,
      ],
    ),
  );
}
