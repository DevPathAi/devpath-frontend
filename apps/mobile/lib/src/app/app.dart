import 'package:app_links/app_links.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/application/auth_controller.dart';
import '../features/auth/application/deep_link_service.dart';
import '../providers/theme_provider.dart';
import 'router.dart';

/// 루트 위젯. 시작 시 딥링크 서비스를 가동해 OAuth 콜백 토큰을 AuthController로 흘린다.
class DevPathMobileApp extends ConsumerStatefulWidget {
  const DevPathMobileApp({super.key});

  @override
  ConsumerState<DevPathMobileApp> createState() => _DevPathMobileAppState();
}

class _DevPathMobileAppState extends ConsumerState<DevPathMobileApp> {
  DeepLinkService? _deepLinks;

  @override
  void initState() {
    super.initState();
    final service = DeepLinkService(
      AppLinks(),
      onCode: (code) => ref
          .read(authControllerProvider.notifier)
          .completeFromCode(code),
    );
    _deepLinks = service;
    // 플랫폼 채널이 없는 환경(테스트 등)에서도 앱 부팅을 막지 않는다.
    service.start().catchError((_) {});
  }

  @override
  void dispose() {
    _deepLinks?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'DevPath AI',
      debugShowCheckedModeBanner: false,
      theme: DpTheme.light(),
      darkTheme: DpTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
