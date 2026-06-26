import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// OAuth 인가 URL을 외부 브라우저로 여는 추상화.
/// 테스트는 [oauthLauncherProvider]를 Fake로 오버라이드한다(url_launcher는 플랫폼 채널).
abstract interface class OAuthLauncher {
  Future<void> launch(String url);
}

class UrlLauncherOAuthLauncher implements OAuthLauncher {
  const UrlLauncherOAuthLauncher();

  @override
  Future<void> launch(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }
}

final oauthLauncherProvider = Provider<OAuthLauncher>(
  (ref) => const UrlLauncherOAuthLauncher(),
);
