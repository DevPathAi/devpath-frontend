import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';

/// 온보딩 자리(실구현=P4b ONB-001/002). 로그아웃으로 게이트 흐름 확인 가능.
class OnboardingPlaceholder extends ConsumerWidget {
  const OnboardingPlaceholder({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('온보딩'),
        actions: [
          TextButton(
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
            child: const Text('로그아웃'),
          ),
        ],
      ),
      body: const DpEmpty(
        icon: DpIcons.path,
        title: '진단을 시작해요',
        message: '온보딩·진단 화면은 P4b에서 제공됩니다.',
      ),
    );
  }
}
