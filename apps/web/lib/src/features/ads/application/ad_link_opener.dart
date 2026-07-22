import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ad_link_opener_web.dart'
    if (dart.library.io) 'ad_link_opener_stub.dart';

/// 광고 클릭 시 외부 링크를 새 탭으로 연다. 테스트에서 Fake로 교체.
abstract interface class AdLinkOpener {
  void open(String url);
}

final adLinkOpenerProvider = Provider<AdLinkOpener>(
  (ref) => createAdLinkOpener(),
);
