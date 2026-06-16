import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/auth_controller.dart';
import '../state/auth_state.dart';

class AdminLoginPage extends ConsumerWidget {
  const AdminLoginPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(adminAuthProvider);
    final err = s is AdminUnauthed ? s.error : null;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'DevPath 운영 콘솔',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              if (err != null) ...[
                const SizedBox(height: DpSpacing.md),
                Text(err, style: TextStyle(color: context.dpColors.danger)),
              ],
              const SizedBox(height: DpSpacing.xl),
              FilledButton(
                onPressed: () => ref.read(adminAuthProvider.notifier).login(),
                child: const Text('관리자 로그인 (목)'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
