import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import '../theme/dp_colors.dart';
import '../theme/dp_spacing.dart';

/// 키-값 한 쌍. 값은 태그나 진행 바가 올 수 있어 Widget 이다.
typedef DpKeyValue = ({String key, Widget value});

/// 요약 키-값 목록(시안 `.kv`) — 좌측 키, 우측 값.
///
/// 값을 우측 정렬 + 등폭 숫자로 두는 이유는 여러 줄이 세로로 쌓였을 때
/// 자릿수가 맞아야 읽히기 때문이다(시안 `.kv dd`).
class DpKeyValues extends StatelessWidget {
  const DpKeyValues({super.key, required this.entries});

  final List<DpKeyValue> entries;

  @override
  Widget build(BuildContext context) {
    final c = context.dpColors;
    final text = Theme.of(context).textTheme;

    return Padding(
      key: const ValueKey('dp-key-values'),
      padding: const EdgeInsets.symmetric(
        vertical: DpSpacing.md,
        horizontal: DpSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            if (i > 0) const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entries[i].key,
                  style: text.bodyMedium?.copyWith(color: c.textSecondary),
                ),
                const SizedBox(width: DpSpacing.lg),
                Expanded(
                  child: DefaultTextStyle.merge(
                    textAlign: TextAlign.right,
                    style: text.bodyMedium?.copyWith(
                      color: c.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: entries[i].value,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
