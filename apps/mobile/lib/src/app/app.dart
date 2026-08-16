import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/application/auth_controller.dart';
import '../features/auth/application/deep_link_service.dart';
import '../features/auth/application/pending_deep_link_controller.dart';
import '../features/auth/state/auth_state.dart';
import '../features/notifications/application/notification_controller.dart';
import '../features/notifications/application/push_consent_coordinator.dart';
import '../features/learning/application/content_progress_sync_controller.dart';
import '../providers/theme_provider.dart';
import 'router.dart';

/// 루트 위젯. 시작 시 딥링크 서비스를 가동해 OAuth 콜백 토큰을 AuthController로 흘린다.
class DevPathMobileApp extends ConsumerStatefulWidget {
  const DevPathMobileApp({super.key});

  @override
  ConsumerState<DevPathMobileApp> createState() => _DevPathMobileAppState();
}

class _DevPathMobileAppState extends ConsumerState<DevPathMobileApp>
    with WidgetsBindingObserver {
  DeepLinkService? _deepLinks;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final service = DeepLinkService(
      AppLinksDeepLinkSource(AppLinks()),
      onCode: (code) =>
          ref.read(authControllerProvider.notifier).completeFromCode(code),
      onRoute: (location) {
        unawaited(
          ref.read(pendingDeepLinkProvider.notifier).capture(location).then((
            captured,
          ) {
            if (captured && mounted) {
              ref.read(routerProvider).go(location);
            }
          }),
        );
      },
    );
    _deepLinks = service;
    // 플랫폼 채널이 없는 환경(테스트 등)에서도 앱 부팅을 막지 않는다.
    service.start().catchError((_) {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _deepLinks?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final auth = ref.read(authControllerProvider);
    ref.read(pushConsentCoordinatorProvider).resume(auth);
    final needsRefresh = switch (auth) {
      AuthSessionUnavailable() || AuthOfflineAuthenticated() => true,
      AuthAuthenticated(:final user) =>
        user.consentStatus != ConsentStatus.done ||
            user.onboardingStatus != OnboardingStatus.done,
      _ => false,
    };
    if (needsRefresh) {
      unawaited(ref.read(authControllerProvider.notifier).retrySession());
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(pushConsentCoordinatorProvider);
    final router = ref.watch(routerProvider);
    ref.watch(contentProgressSyncControllerProvider);
    ref.listen(notificationControllerProvider, (previous, next) {
      final target = next.navigationTarget;
      if (target == null || previous?.navigationTarget == target) return;
      router.go(target.location);
      ref.read(notificationControllerProvider.notifier).consumeNavigation();
    });
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'Leva',
      debugShowCheckedModeBanner: false,
      theme: DpTheme.light(),
      darkTheme: DpTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
