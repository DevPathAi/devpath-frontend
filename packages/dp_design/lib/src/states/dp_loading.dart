import 'package:flutter/material.dart';

/// 스켈레톤/진행 표시(간소). 상세 shimmer는 사용처에서 확장.
///
/// 스크린리더는 [label](없으면 '불러오는 중')을 liveRegion 으로 읽는다.
class DpLoading extends StatelessWidget {
  const DpLoading({super.key, this.label});
  final String? label;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label ?? '불러오는 중',
    liveRegion: true,
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          if (label != null) ...[
            const SizedBox(height: 12),
            ExcludeSemantics(
              child: Text(label!, style: Theme.of(context).textTheme.bodySmall),
            ),
          ],
        ],
      ),
    ),
  );
}
