import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/app_config.dart';
import '../../mission/state/mobile_mission_route.dart';

enum WebActivationStep { consent, diagnostic }

abstract interface class WebActivationLauncher {
  Future<void> launch(Uri uri);
}

class UrlLauncherWebActivation implements WebActivationLauncher {
  const UrlLauncherWebActivation();

  @override
  Future<void> launch(Uri uri) async {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) throw StateError('웹 activation을 열지 못했습니다.');
  }
}

Uri buildWebActivationUri(
  AppConfig config, {
  required WebActivationStep step,
  String? pendingLocation,
}) {
  final base = Uri.parse(config.webAppUrl);
  final allowedScheme =
      base.scheme == 'https' ||
      (config.useMock && base.scheme == 'http' && base.host == 'localhost');
  if (!allowedScheme ||
      base.host.isEmpty ||
      base.userInfo.isNotEmpty ||
      (base.path.isNotEmpty && base.path != '/') ||
      base.hasQuery ||
      base.hasFragment) {
    throw const FormatException(
      'WEB_APP_URL must be an allowlisted web origin',
    );
  }
  if (pendingLocation != null &&
      MobileMissionRoute.tryParse(pendingLocation) == null) {
    throw const FormatException('mobile_return_to must be a canonical route');
  }
  final path = switch (step) {
    WebActivationStep.consent => '/consent',
    WebActivationStep.diagnostic => '/diagnostic',
  };
  return Uri(
    scheme: base.scheme,
    host: base.host,
    port: base.hasPort ? base.port : null,
    path: path,
    queryParameters: pendingLocation == null
        ? null
        : {'mobile_return_to': pendingLocation},
  );
}

final webActivationLauncherProvider = Provider<WebActivationLauncher>(
  (ref) => const UrlLauncherWebActivation(),
);
