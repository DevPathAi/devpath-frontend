import 'dart:convert';

import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/application/auth_controller.dart';
import '../../auth/state/auth_state.dart';
import '../application/diagnostic_controller.dart';
import '../state/diagnostic_state.dart';

class DiagnosticPage extends ConsumerStatefulWidget {
  const DiagnosticPage({super.key});

  @override
  ConsumerState<DiagnosticPage> createState() => _DiagnosticPageState();
}

class _DiagnosticPageState extends ConsumerState<DiagnosticPage> {
  bool _triggeredClaim = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(diagnosticControllerProvider);
    final notifier = ref.read(diagnosticControllerProvider.notifier);
    final auth = ref.watch(authControllerProvider);

    // 결과 표시 시 경로 화면으로 이동(#3 자리).
    ref.listen(diagnosticControllerProvider, (_, next) {
      if (next is DiagnosticResultState) context.go('/path');
    });

    // OAuth 복귀: 인증됨 + 보관된 guest claim 존재 + 아직 미시작 → claim 1회.
    if (!_triggeredClaim &&
        state is DiagnosticIdle &&
        auth is AuthAuthenticated &&
        notifier.hasPendingGuestClaim) {
      _triggeredClaim = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => notifier.claimAfterLogin(),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('실력 진단')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(DpSpacing.xl),
            child: switch (state) {
              DiagnosticIdle() => _StartView(auth: auth, notifier: notifier),
              DiagnosticLoading() => const Center(
                child: CircularProgressIndicator(),
              ),
              DiagnosticQuestion(:final next) => _QuestionView(
                next: next,
                notifier: notifier,
              ),
              DiagnosticGateSignup() => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '결과를 보려면 로그인하세요',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: DpSpacing.lg),
                  FilledButton(
                    onPressed: () =>
                        ref.read(authControllerProvider.notifier).login(),
                    child: const Text('GitHub로 로그인'),
                  ),
                ],
              ),
              DiagnosticResultState(:final result) => Text(
                '진단 레벨: ${result.diagnosedLevel}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              DiagnosticError(:final message) => Text(
                message,
                style: TextStyle(color: context.dpColors.danger),
              ),
            },
          ),
        ),
      ),
    );
  }
}

class _StartView extends StatelessWidget {
  const _StartView({required this.auth, required this.notifier});
  final AuthState auth;
  final DiagnosticController notifier;

  @override
  Widget build(BuildContext context) {
    final isMember = auth is AuthAuthenticated;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('실력 진단 15문항', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: DpSpacing.lg),
        FilledButton(
          onPressed: () => isMember
              ? notifier.startAsMember('BACKEND_SPRING')
              : notifier.startAsGuest('BACKEND_SPRING'),
          child: const Text('진단 시작하기'),
        ),
      ],
    );
  }
}

class _QuestionView extends StatelessWidget {
  const _QuestionView({required this.next, required this.notifier});
  final NextQuestion next;
  final DiagnosticController notifier;

  List<String> _options(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) return decoded.map((e) => e.toString()).toList();
    } catch (_) {}
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    final q = next.question;
    final options = _options(q.options);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${next.index} / ${next.total} · 진단',
          style: Theme.of(context).textTheme.labelMedium,
        ),
        const SizedBox(height: DpSpacing.md),
        Text(q.content, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: DpSpacing.lg),
        if (options.isEmpty)
          FilledButton(
            onPressed: () =>
                notifier.submitAnswer(q.id, '{"correct":0}', timeSpentSec: 5),
            child: const Text('답안 제출'),
          )
        else
          for (var i = 0; i < options.length; i++) ...[
            OutlinedButton(
              onPressed: () => notifier.submitAnswer(
                q.id,
                '{"correct":$i}',
                timeSpentSec: 5,
              ),
              child: Text(options[i]),
            ),
            const SizedBox(height: DpSpacing.sm),
          ],
        const SizedBox(height: DpSpacing.md),
        const Divider(),
        TextButton(
          onPressed: () => notifier.skip(q.id),
          child: const Text('잘 모르겠어요'),
        ),
      ],
    );
  }
}
