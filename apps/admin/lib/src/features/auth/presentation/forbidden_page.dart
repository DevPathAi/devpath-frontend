import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/auth_controller.dart';
import 'admin_access_frame.dart';

class AdminForbiddenPage extends ConsumerWidget {
  const AdminForbiddenPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => AdminAccessFrame(
    title: '이 계정으로는 접근할 수 없어요',
    description: '운영 콘솔은 ADMIN 또는 OWNER 권한이 있는 계정만 사용할 수 있습니다.',
    child: FilledButton(
      onPressed: () => ref.read(adminAuthProvider.notifier).logout(),
      child: const Text('다른 계정으로 로그인'),
    ),
  );
}
