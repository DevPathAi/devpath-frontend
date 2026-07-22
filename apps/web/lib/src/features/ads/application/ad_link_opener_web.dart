import 'package:web/web.dart' as web;

import 'ad_link_opener.dart';

/// 웹: 새 탭으로 링크 오픈.
class _WebAdLinkOpener implements AdLinkOpener {
  const _WebAdLinkOpener();

  @override
  void open(String url) {
    web.window.open(url, '_blank');
  }
}

AdLinkOpener createAdLinkOpener() => const _WebAdLinkOpener();
