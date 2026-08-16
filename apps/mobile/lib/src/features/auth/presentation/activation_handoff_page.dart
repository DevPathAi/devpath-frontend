import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/api_providers.dart';
import '../application/auth_controller.dart';
import '../application/pending_deep_link_controller.dart';
import '../application/web_activation_launcher.dart';

class ActivationHandoffPage extends ConsumerWidget {
  const ActivationHandoffPage({super.key, required this.step});

  final WebActivationStep step;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isConsent = step == WebActivationStep.consent;
    final pending = ref.watch(pendingDeepLinkProvider);

    Future<void> openWeb() async {
      try {
        final uri = buildWebActivationUri(
          ref.read(appConfigProvider),
          step: step,
          pendingLocation: pending,
        );
        await ref.read(webActivationLauncherProvider).launch(uri);
      } on Object {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('웹 화면을 열지 못했어요. 다시 시도해 주세요.')),
        );
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Leva')),
      body: DpStateScaffold(
        icon: isConsent ? DpIcons.account : DpIcons.path,
        title: isConsent ? '필수 동의를 먼저 완료해 주세요' : '웹에서 진단을 이어가세요',
        message: isConsent
            ? '약관과 개인정보 동의는 웹에서 안전하게 완료합니다. 돌아오면 같은 미션 링크를 이어서 열어요.'
            : '모바일에서 별도 진단을 만들지 않습니다. 웹에서 완료한 진단과 학습 경로를 그대로 이어받아요.',
        actionLabel: isConsent ? '웹에서 동의하기' : '웹에서 진단 이어가기',
        onAction: openWeb,
        secondaryActionLabel: '완료했어요 · 다시 확인',
        onSecondaryAction: () =>
            ref.read(authControllerProvider.notifier).retrySession(),
      ),
    );
  }
}
