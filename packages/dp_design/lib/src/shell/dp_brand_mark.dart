import 'package:flutter/material.dart';

import '../icons/dp_icons.dart';
import '../theme/dp_colors.dart';

/// 앱 셸과 인증 화면에서 공유하는 Leva 심볼.
/// 단색 사각형 대신 경로를 뜻하는 기호와 깊이 있는 인디고 면을 결합한다.
class DpBrandMark extends StatelessWidget {
  const DpBrandMark({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.dpColors;
    return Semantics(
      image: true,
      label: 'Leva',
      child: Container(
        key: const ValueKey('leva-brand-mark'),
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [c.primary, c.primaryTextStrong],
          ),
          borderRadius: BorderRadius.circular(size * 0.34),
          boxShadow: [
            BoxShadow(
              color: c.primary.withValues(alpha: 0.24),
              blurRadius: size * 0.45,
              offset: Offset(0, size * 0.16),
            ),
          ],
        ),
        child: Icon(
          DpIcons.path,
          size: size * 0.58,
          color: Colors.white,
          fill: 1,
          weight: 600,
        ),
      ),
    );
  }
}
