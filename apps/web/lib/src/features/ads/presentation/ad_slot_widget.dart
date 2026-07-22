import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../application/ad_link_opener.dart';
import '../data/ad_view.dart';
import '../data/ads_source.dart';

/// 슬롯 공용 광고 위젯. fail-silent: 광고 없으면 아무것도 그리지 않는다.
class AdSlotWidget extends ConsumerStatefulWidget {
  const AdSlotWidget({super.key, required this.slot});
  final String slot;

  @override
  ConsumerState<AdSlotWidget> createState() => _AdSlotWidgetState();
}

class _AdSlotWidgetState extends ConsumerState<AdSlotWidget> {
  AdView? _ad;
  bool _impressed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetch());
  }

  Future<void> _fetch() async {
    final ad = await ref.read(adFetchProvider)(widget.slot);
    if (!mounted) return;
    setState(() => _ad = ad);
  }

  void _onVisible(double fraction) {
    if (_impressed || _ad == null) return;
    if (fraction >= 0.5) {
      _impressed = true;
      ref.read(adEventProvider)(_ad!.id, 'IMPRESSION');
    }
  }

  void _onTap() {
    final ad = _ad;
    if (ad == null) return;
    ref.read(adEventProvider)(ad.id, 'CLICK');
    ref.read(adLinkOpenerProvider).open(ad.linkUrl);
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (ad == null) return const SizedBox.shrink();
    final c = context.dpColors;
    final text = Theme.of(context).textTheme;

    return VisibilityDetector(
      key: Key('ad-${widget.slot}-${ad.id}'),
      onVisibilityChanged: (info) => _onVisible(info.visibleFraction),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: DpSpacing.sm),
        child: InkWell(
          onTap: _onTap,
          child: Padding(
            padding: const EdgeInsets.all(DpSpacing.md),
            child: Row(
              children: [
                if (ad.imageUrl != null)
                  Padding(
                    padding: const EdgeInsets.only(right: DpSpacing.md),
                    child: Image.network(
                      ad.imageUrl!,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const SizedBox(width: 64, height: 64),
                    ),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '광고',
                        style: text.labelSmall?.copyWith(
                          color: c.textSecondary,
                        ),
                      ),
                      const SizedBox(height: DpSpacing.xs),
                      Text(ad.title, style: text.bodyMedium),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
