import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/auth_controller.dart';

/// OAuth 콜백 착지 페이지. 마운트 시 bootstrapFromCallback()을 호출해
/// /auth/refresh로 세션을 복원한다. 복원 완료 후 게이트가 상태에 따라 분기한다.
class AuthCallbackPage extends ConsumerStatefulWidget {
  const AuthCallbackPage({super.key});

  @override
  ConsumerState<AuthCallbackPage> createState() => _AuthCallbackPageState();
}

class _AuthCallbackPageState extends ConsumerState<AuthCallbackPage> {
  @override
  void initState() {
    super.initState();
    // 마운트 후 첫 프레임에 실행 — router redirect가 완료된 뒤 호출된다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authControllerProvider.notifier).bootstrapFromCallback();
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
