import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/auth_controller.dart';

/// OAuth 콜백 착지 페이지. 마운트 시 bootstrapFromCallback()을 호출해
/// /auth/refresh로 세션을 복원한다. 복원 완료 후 게이트가 상태에 따라 분기한다.
class AdminAuthCallbackPage extends ConsumerStatefulWidget {
  const AdminAuthCallbackPage({super.key});

  @override
  ConsumerState<AdminAuthCallbackPage> createState() => _S();
}

class _S extends ConsumerState<AdminAuthCallbackPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(adminAuthProvider.notifier).bootstrapFromCallback();
    });
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}
