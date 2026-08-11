import 'package:web/web.dart' as web;

import 'external_link_opener.dart';

/// 웹: 새 탭으로 링크 오픈.
class _WebExternalLinkOpener implements ExternalLinkOpener {
  const _WebExternalLinkOpener();

  @override
  void open(String url) {
    web.window.open(url, '_blank');
  }
}

ExternalLinkOpener createExternalLinkOpener() => const _WebExternalLinkOpener();
