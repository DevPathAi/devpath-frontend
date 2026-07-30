import 'package:flutter/material.dart';

import '../theme/dp_tokens.dart';

/// 웹 본문이 큰 화면에서 전체 폭으로 퍼지지 않도록 상단 중앙에 최대폭 제약.
/// (로드맵 §2.2·안티패턴 "전체 너비 확장" 대응.)
class DpMaxWidth extends StatelessWidget {
  const DpMaxWidth({super.key, required this.child, this.maxWidth});

  final Widget child;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final w = maxWidth ?? context.appTokens.contentMaxWidth;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: w),
        child: SizedBox(width: double.infinity, child: child),
      ),
    );
  }
}
