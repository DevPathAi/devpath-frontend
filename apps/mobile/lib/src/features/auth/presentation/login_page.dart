import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/api_providers.dart';
import '../application/auth_controller.dart';
import '../state/auth_state.dart';

/// 로그인. 목 모드는 mockLogin(가짜 토큰→/users/me), 실모드는 OAuth 외부 브라우저.
class LoginPage extends ConsumerWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final useMock = ref.watch(appConfigProvider).useMock;
    final error = auth is AuthUnauthenticated ? auth.error : null;
    final notifier = ref.read(authControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('DevPath AI')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (error != null) ...[
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  error,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
            FilledButton(
              onPressed: () =>
                  useMock ? notifier.mockLogin() : notifier.login(),
              child: Text(useMock ? 'GitHub로 계속하기 (목)' : 'GitHub로 계속하기'),
            ),
          ],
        ),
      ),
    );
  }
}
