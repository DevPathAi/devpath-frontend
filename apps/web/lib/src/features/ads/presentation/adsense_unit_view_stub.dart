import 'package:flutter/widgets.dart';

import 'adsense_unit_view.dart' show AdSenseHandle;

/// 비웹/테스트: 애드센스를 로드하지 않는다. 높이 0 그대로 남으므로 화면에 아무것도 없다.
AdSenseHandle createAdSenseHandle({
  required String slotId,
  required void Function(String status, double height) onResolved,
}) => _StubHandle();

class _StubHandle implements AdSenseHandle {
  @override
  Widget get view => const SizedBox.shrink();

  @override
  void dispose() {}
}
