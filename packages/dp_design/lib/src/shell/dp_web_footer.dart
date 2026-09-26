import 'package:flutter/material.dart';

import '../layout/dp_max_width.dart';
import '../theme/dp_colors.dart';
import '../theme/dp_spacing.dart';

/// 푸터 링크.
typedef DpFooterLink = ({String label, VoidCallback onTap});

/// 웹 문법의 푸터(스펙 §5.3, 시안 `.ft`). 상단 경계선 + `surface` 배경,
/// 안쪽은 `contentMaxWidth` 중앙 정렬.
///
/// 셸 하단에 **고정**된다(사용자 결정 2026-09-26). 시안은 내용 끝에 붙지만,
/// Flutter 는 화면마다 자기 스크롤뷰를 가져서 같은 거동을 얻으려면 모든 화면을
/// 고쳐야 한다 — 그것은 P4 의 일이다.
class DpWebFooter extends StatelessWidget {
  const DpWebFooter({super.key, required this.notice, required this.links});

  final String notice;
  final List<DpFooterLink> links;

  @override
  Widget build(BuildContext context) {
    final c = context.dpColors;
    final text = Theme.of(context).textTheme;

    return Container(
      key: const ValueKey('web-footer-root'),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: DpMaxWidth(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DpSpacing.xl,
            vertical: DpSpacing.sm,
          ),
          child: Wrap(
            spacing: DpSpacing.lg,
            runSpacing: DpSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // 최소 타깃은 누를 수 있는 것에만 적용된다 — 이 줄은 텍스트다.
              ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: DpDensity.minTarget,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    notice,
                    style: text.labelSmall?.copyWith(color: c.textFaint),
                  ),
                ),
              ),
              for (final link in links)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: link.onTap,
                    borderRadius: BorderRadius.circular(DpRadius.button),
                    child: Container(
                      constraints: const BoxConstraints(
                        minHeight: DpDensity.minTarget,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: DpSpacing.xs,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        link.label,
                        style: text.labelSmall?.copyWith(
                          color: c.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
