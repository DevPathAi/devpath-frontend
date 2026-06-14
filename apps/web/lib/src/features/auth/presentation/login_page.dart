import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/theme_provider.dart';
import '../application/auth_controller.dart';
import '../state/auth_state.dart';

/// OAuth(목) 로그인. 우상단 테마 토글, 실패 시 인라인 에러.
class LoginPage extends ConsumerWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final mode = ref.watch(themeModeProvider);
    final c = context.dpColors;
    final error = auth is AuthUnauthenticated ? auth.error : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('DevPath AI'),
        actions: [
          IconButton(
            icon: Icon(
              mode == ThemeMode.dark ? DpIcons.lightMode : DpIcons.darkMode,
            ),
            tooltip: '테마 전환',
            onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(DpSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '학습을 시작해요',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: DpSpacing.sm),
                Text(
                  'GitHub 계정으로 계속하세요',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: c.textSecondary),
                ),
                if (error != null) ...[
                  const SizedBox(height: DpSpacing.lg),
                  Text(
                    error,
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: c.danger),
                  ),
                ],
                const SizedBox(height: DpSpacing.xl),
                FilledButton(
                  onPressed: () =>
                      ref.read(authControllerProvider.notifier).login(),
                  child: const Text('GitHub로 계속하기 (목)'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
