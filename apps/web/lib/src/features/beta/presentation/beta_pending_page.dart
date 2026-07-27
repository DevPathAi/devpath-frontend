import 'dart:async';

import 'package:dp_core/dp_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../providers/api_providers.dart';
import '../../auth/application/auth_controller.dart';

/// 미승인(BETA_PENDING) 사용자 대기 페이지. 5초 주기로 GET /beta/status를 폴링해
/// APPROVED면 자동 재-OAuth(login(provider)), EXPIRED면 재로그인 버튼을 노출한다.
class BetaPendingPage extends ConsumerStatefulWidget {
  const BetaPendingPage({super.key});

  @override
  ConsumerState<BetaPendingPage> createState() => _BetaPendingPageState();
}

class _BetaPendingPageState extends ConsumerState<BetaPendingPage> {
  Timer? _timer;
  bool _expired = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _poll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    try {
      final data = await ref
          .read(apiClientProvider)
          .get<Map<String, dynamic>>('/beta/status');
      if (!mounted) return;
      final status = BetaStatus.fromJson(data);
      switch (status.status) {
        case BetaStatusKind.approved:
          _timer?.cancel();
          final p = status.provider;
          if (p != null) {
            ref.read(authControllerProvider.notifier).login(provider: p);
          } else {
            context.go('/login');
          }
        case BetaStatusKind.expired:
          _timer?.cancel();
          setState(() => _expired = true);
        case BetaStatusKind.pending:
          break;
      }
    } catch (_) {
      // 일시 오류는 무시하고 다음 주기 재시도.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('DevPath AI')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _expired ? Icons.lock_clock : Icons.hourglass_top,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  '베타 대기 중',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  _expired
                      ? '대기 세션이 만료되었어요. 승인 여부는 이메일로 안내됩니다. 다시 로그인해 확인하세요.'
                      : '베타 대기자 명단에 등록되었어요. 승인되면 이메일로 알려드리고, 이 화면에서 자동으로 입장합니다.',
                  textAlign: TextAlign.center,
                ),
                if (_expired) ...[
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => context.go('/login'),
                    child: const Text('다시 로그인'),
                  ),
                ] else ...[
                  const SizedBox(height: 24),
                  const CircularProgressIndicator(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
