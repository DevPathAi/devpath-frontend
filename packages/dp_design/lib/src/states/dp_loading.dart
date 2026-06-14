import 'package:flutter/material.dart';

/// 스켈레톤/진행 표시(간소). 상세 shimmer는 사용처에서 확장.
class DpLoading extends StatelessWidget {
  const DpLoading({super.key, this.label});
  final String? label;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(),
        if (label != null) ...[
          const SizedBox(height: 12),
          Text(label!, style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
    ),
  );
}
