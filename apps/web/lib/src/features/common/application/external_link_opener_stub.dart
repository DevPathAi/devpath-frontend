import 'external_link_opener.dart';

class _StubExternalLinkOpener implements ExternalLinkOpener {
  const _StubExternalLinkOpener();

  @override
  void open(String url) {
    throw UnsupportedError(
      'ExternalLinkOpener.open is not supported on non-web platforms. '
      'Override externalLinkOpenerProvider in tests with a Fake.',
    );
  }
}

ExternalLinkOpener createExternalLinkOpener() =>
    const _StubExternalLinkOpener();
