import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'external_link_opener_web.dart'
    if (dart.library.io) 'external_link_opener_stub.dart';

/// 외부 링크를 새 탭으로 연다. 광고 클릭과 약관·처리방침 전문 열람이 함께 쓴다.
/// 테스트에서 Fake로 교체.
abstract interface class ExternalLinkOpener {
  void open(String url);
}

final externalLinkOpenerProvider = Provider<ExternalLinkOpener>(
  (ref) => createExternalLinkOpener(),
);
