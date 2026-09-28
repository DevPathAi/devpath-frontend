import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../diagnostic/application/diagnostic_controller.dart';
import '../application/auth_controller.dart';
import '../state/auth_state.dart';

/// OAuth 콜백 착지 페이지. 마운트 시 bootstrapFromCallback()을 호출해
/// /auth/refresh로 세션을 복원한다. 복원 완료 후 게이트가 상태에 따라 분기한다.
class AuthCallbackPage extends ConsumerStatefulWidget {
  const AuthCallbackPage({super.key});

  @override
  ConsumerState<AuthCallbackPage> createState() => _AuthCallbackPageState();
}

class _AuthCallbackPageState extends ConsumerState<AuthCallbackPage> {
  bool _reportedFailure = false;

  @override
  void initState() {
    super.initState();
    // 마운트 후 첫 프레임에 실행 — router redirect가 완료된 뒤 호출된다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(authControllerProvider.notifier).bootstrapFromCallback();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    if (auth case AuthUnauthenticated(:final error)) {
      final failureCopy = error ?? '로그인 상태를 확인하지 못했어요. 다시 시도해 주세요.';
      if (!_reportedFailure) {
        _reportedFailure = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ref
              .read(diagnosticControllerProvider.notifier)
              .markOAuthFailure('로그인을 완료하지 못했어요. 진단 결과는 이 탭에 그대로 남아 있어요.');
        });
      }
      return _CallbackFrame(
        children: [
          Text(
            '로그인을 완료하지 못했어요',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: DpSpacing.sm),
          const Text(
            '진단 결과는 이 탭에 남아 있습니다. 다시 확인하거나 결과로 돌아갈 수 있어요.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: DpSpacing.sm),
          Text(
            failureCopy,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.dpColors.danger),
          ),
          const SizedBox(height: DpSpacing.xl),
          FilledButton(
            onPressed: () => ref
                .read(authControllerProvider.notifier)
                .bootstrapFromCallback(),
            child: const Text('로그인 다시 확인'),
          ),
          const SizedBox(height: DpSpacing.sm),
          OutlinedButton(
            onPressed: () => context.go('/diagnostic'),
            child: const Text('진단 결과로 돌아가기'),
          ),
        ],
      );
    }
    return const _CallbackFrame(children: [DpLoading(label: '로그인을 확인하는 중')]);
  }
}

/// 시안 `beta` 파생 — `.narrow.center` 중앙 정렬 한 열.
/// 진행·실패 두 상태가 같은 프레임을 쓴다(폭이 상태에 따라 달라지면 눈에 띈다).
class _CallbackFrame extends StatelessWidget {
  const _CallbackFrame({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: ConstrainedBox(
        key: const ValueKey('auth-callback-narrow'),
        constraints: BoxConstraints(
          maxWidth: context.appTokens.readableMaxWidth,
        ),
        child: Padding(
          padding: const EdgeInsets.all(DpSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: children,
          ),
        ),
      ),
    ),
  );
}
