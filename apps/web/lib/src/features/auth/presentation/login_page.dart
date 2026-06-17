import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/api_providers.dart';
import '../../../providers/theme_provider.dart';
import '../application/auth_controller.dart';
import '../state/auth_state.dart';

/// OAuth(목) 로그인. 우상단 테마 토글, 실패 시 인라인 에러.
/// 목 모드(useMock=true)에서는 버튼 레이블에 "(목)" 접미사를 추가하고
/// 브라우저 리다이렉트 대신 bootstrapFromCallback()으로 즉시 인증한다.
class LoginPage extends ConsumerWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final mode = ref.watch(themeModeProvider);
    final useMock = ref.watch(appConfigProvider).useMock;
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
                  onPressed: () => useMock
                      ? ref
                            .read(authControllerProvider.notifier)
                            .bootstrapFromCallback()
                      : ref.read(authControllerProvider.notifier).login(),
                  child: Text(useMock ? 'GitHub로 계속하기 (목)' : 'GitHub로 계속하기'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
