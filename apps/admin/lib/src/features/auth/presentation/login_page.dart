import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/auth_controller.dart';
import '../state/auth_state.dart';
import 'admin_access_frame.dart';

class AdminLoginPage extends ConsumerWidget {
  const AdminLoginPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(adminAuthProvider);
    final err = s is AdminUnauthed ? s.error : null;
    return AdminAccessFrame(
      title: '관리자 로그인',
      description: '승인된 운영 계정으로 계속하세요.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (err != null) ...[
            Semantics(
              liveRegion: true,
              label: '로그인 실패: $err',
              child: ExcludeSemantics(
                child: Text(
                  err,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.dpColors.danger,
                  ),
                ),
              ),
            ),
            const SizedBox(height: DpSpacing.md),
          ],
          FilledButton(
            onPressed: () => ref.read(adminAuthProvider.notifier).login(),
            child: const Text('GitHub로 관리자 로그인'),
          ),
          const SizedBox(height: DpSpacing.sm),
          OutlinedButton(
            onPressed: () =>
                ref.read(adminAuthProvider.notifier).login(provider: 'google'),
            child: const Text('Google로 관리자 로그인'),
          ),
        ],
      ),
    );
  }
}
