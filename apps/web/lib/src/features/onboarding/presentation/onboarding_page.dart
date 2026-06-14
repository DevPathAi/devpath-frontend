import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/onboarding_controller.dart';
import '../state/onboarding_state.dart';

/// 최소 진단 화면(ONB). 제출 성공 시 PATH 생성으로 이동.
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final _handle = TextEditingController();

  @override
  void dispose() {
    _handle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingControllerProvider);
    final c = context.dpColors;

    // 제출 완료 → PATH 생성 화면으로(게이트는 onboarding 완료 시 /onboarding 강제 안 함).
    ref.listen(onboardingControllerProvider, (_, next) {
      if (next is OnboardingDone) context.go('/path');
    });

    final submitting = state is OnboardingSubmitting;

    return Scaffold(
      appBar: AppBar(title: const Text('진단')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(DpSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'GitHub 계정을 분석해 경로를 만들어요',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: DpSpacing.lg),
                TextField(
                  controller: _handle,
                  enabled: !submitting,
                  decoration: const InputDecoration(
                    labelText: 'GitHub 핸들',
                    hintText: '예: jisoo-dev',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (state is OnboardingError) ...[
                  const SizedBox(height: DpSpacing.sm),
                  Text(
                    state.message,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: c.danger),
                  ),
                ],
                const SizedBox(height: DpSpacing.lg),
                FilledButton(
                  onPressed: submitting
                      ? null
                      : () => ref
                            .read(onboardingControllerProvider.notifier)
                            .submit(githubHandle: _handle.text.trim()),
                  child: Text(submitting ? '분석 준비 중…' : '진단 시작하기'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
