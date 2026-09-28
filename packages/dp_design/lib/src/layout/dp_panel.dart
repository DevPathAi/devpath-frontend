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
      // 패널이 스스로 잉크 표면을 갖는다. `MaterialType.transparency` 는 아무
      // 배경도 그리지 않으므로 표면 색·테두리는 위 Container 것 그대로이고,
      // 잉크만 이 경계 안에서 일어나 위의 clipBehavior 로 잘린다. 이 한 겹이
      // 없으면 안쪽의 `ListTile`·`InkWell` 이 가장 가까운 Material(보통
      // `Scaffold`)에 그려 패널 표면이 그 잉크를 덮고, `ListTile` 은 프레임워크
      // 단언에 걸린다(P4 Task 3 의 실패 7건이 전부 이 원인이었다).
      child: Material(
        type: MaterialType.transparency,
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
                // heading 플래그는 제목행 전체가 아니라 `DpPanelTitle` 이 자기
                // 텍스트에만 붙인다. 여기서 감싸면 제목 옆에 액션이 함께 있을 때
                // 자식 노드가 둘이라 병합되지 않고 **라벨 없는 header 컨테이너**가
                // 생긴다(2026-09-17 함정 1 「heading+button 병합」과 같은 뿌리).
                child: DefaultTextStyle.merge(
                  style: text.titleSmall?.copyWith(color: c.textPrimary),
                  child: title!,
                ),
              ),
            Padding(padding: padding ?? EdgeInsets.zero, child: child),
          ],
        ),
      ),
    );
  }
}

/// 패널 제목 텍스트(시안 `.panel>h3`). heading 플래그를 **이 텍스트에만** 준다.
///
/// `DpPanel.title` 에 액션을 함께 넣을 때 제목행 전체를 `Semantics(header: true)`
/// 로 감싸면, 자식 노드가 둘 이상이라 병합되지 않고 라벨 없는 header 컨테이너가
/// 생긴다. 제목만 감싸면 그 함정이 닫힌다.
class DpPanelTitle extends StatelessWidget {
  const DpPanelTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) =>
      Semantics(header: true, child: Text(text));
}
