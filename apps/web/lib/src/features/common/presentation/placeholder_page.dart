import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';

/// P4b~P4d에서 실구현될 화면의 임시 자리(빈 상태 카피 규약 준수).
///
/// 시안 `beta` 파생 — `.narrow.center` 중앙 정렬 한 열. 넓은 화면에서 빈 상태가
/// 본문 폭 전체로 퍼지면 「아직 없다」가 화면을 지배한다.
class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({super.key, required this.title, required this.icon});
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      key: const ValueKey('placeholder-narrow'),
      constraints: BoxConstraints(maxWidth: context.appTokens.readableMaxWidth),
      child: Padding(
        padding: const EdgeInsets.all(DpSpacing.xl),
        child: DpEmpty(icon: icon, title: title, message: '곧 제공됩니다.'),
      ),
    ),
  );
}
