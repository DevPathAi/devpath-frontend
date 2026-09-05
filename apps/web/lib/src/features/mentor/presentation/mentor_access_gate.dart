import 'dart:async';

import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/mentor_access_controller.dart';
import '../state/mentor_access_state.dart';

class MentorAccessGate extends ConsumerStatefulWidget {
  const MentorAccessGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<MentorAccessGate> createState() => _MentorAccessGateState();
}

class _MentorAccessGateState extends ConsumerState<MentorAccessGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(ref.read(mentorAccessControllerProvider.notifier).load());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return switch (ref.watch(mentorAccessControllerProvider)) {
      MentorAccessLoading() => const Scaffold(
        body: DpLoading(label: 'AI 멘토 초대 상태를 확인하는 중'),
      ),
      MentorAccessFailed(:final message) => Scaffold(
        body: DpError(
          title: '초대 상태를 확인하지 못했어요',
          message: message,
          onRetry: () => unawaited(
            ref.read(mentorAccessControllerProvider.notifier).load(),
          ),
        ),
      ),
      MentorAccessReady(:final isActive) when isActive => widget.child,
      MentorAccessReady() => Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(DpSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.mark_email_unread_outlined, size: 48),
                  const SizedBox(height: DpSpacing.lg),
                  Text(
                    'AI 멘토 초대 대기 중',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: DpSpacing.sm),
                  const Text(
                    '보통 1일 안에 초대 메일이 갑니다. 기다리는 동안에도 로드맵 첫 주차 미션을 바로 시작할 수 있어요.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: DpSpacing.xl),
                  FilledButton(
                    onPressed: () => context.go('/path'),
                    child: const Text('이번 주 미션 계속하기'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    };
  }
}
