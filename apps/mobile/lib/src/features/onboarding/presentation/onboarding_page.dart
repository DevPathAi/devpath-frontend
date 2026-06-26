import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/onboarding_controller.dart';
import '../state/onboarding_state.dart';

/// 온보딩(최소 진단) — GitHub 핸들 제출. 성공 시 사용자 갱신 → 게이트가 홈으로 보낸다.
/// (별도 네비게이션 없음: 라우터 `gateRedirect`가 onboardingStatus 변화를 감지해 처리.)
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
    final colors = context.dpColors;
    final submitting = state is OnboardingSubmitting;

    return Scaffold(
      appBar: AppBar(title: const Text('진단')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'GitHub 계정을 분석해 경로를 만들어요',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
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
                  const SizedBox(height: 8),
                  Text(
                    state.message,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: colors.danger),
                  ),
                ],
                const SizedBox(height: 16),
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
