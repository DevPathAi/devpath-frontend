import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/auth_controller.dart';
import '../state/auth_state.dart';

class SessionUnavailablePage extends ConsumerWidget {
  const SessionUnavailablePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final message = switch (auth) {
      AuthSessionUnavailable(:final message) => message,
      _ => '세션을 확인하고 있어요.',
    };
    return Scaffold(
      body: DpError(
        title: '로그인 상태를 확인하지 못했어요',
        message: '$message 저장된 로그인 정보는 지우지 않았어요.',
        onRetry: () => ref.read(authControllerProvider.notifier).retrySession(),
      ),
    );
  }
}
