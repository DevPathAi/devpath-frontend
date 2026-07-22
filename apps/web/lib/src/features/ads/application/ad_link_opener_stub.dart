import 'ad_link_opener.dart';

class _StubAdLinkOpener implements AdLinkOpener {
  const _StubAdLinkOpener();

  @override
  void open(String url) {
    throw UnsupportedError(
      'AdLinkOpener.open is not supported on non-web platforms. '
      'Override adLinkOpenerProvider in tests with a Fake.',
    );
  }
}

AdLinkOpener createAdLinkOpener() => const _StubAdLinkOpener();
