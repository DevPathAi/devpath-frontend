import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/api_providers.dart';
import '../../../providers/theme_provider.dart';
import '../../common/presentation/brand_row.dart';
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
    final error = auth is AuthUnauthenticated ? auth.error : null;

    final themeToggle = IconButton(
      icon: Icon(mode == ThemeMode.dark ? DpIcons.lightMode : DpIcons.darkMode),
      tooltip: '테마 전환',
      onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
    );
    final access = _LoginAccessPanel(
      error: error,
      useMock: useMock,
      onGithub: () => useMock
          ? ref.read(authControllerProvider.notifier).bootstrapFromCallback()
          : ref.read(authControllerProvider.notifier).login(),
      onGoogle: () => useMock
          ? ref.read(authControllerProvider.notifier).bootstrapFromCallback()
          : ref.read(authControllerProvider.notifier).login(provider: 'google'),
    );

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 900;
          if (compact) {
            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: DpSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    brandRow(context, actions: [themeToggle]),
                    const SizedBox(height: DpSpacing.xxl),
                    Center(child: access),
                  ],
                ),
              ),
            );
          }

          return Row(
            children: [
              Expanded(
                flex: 11,
                child: _LoginStoryPanel(themeToggle: themeToggle),
              ),
              Expanded(
                flex: 10,
                child: Center(child: SingleChildScrollView(child: access)),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LoginAccessPanel extends StatelessWidget {
  const _LoginAccessPanel({
    required this.error,
    required this.useMock,
    required this.onGithub,
    required this.onGoogle,
  });

  final String? error;
  final bool useMock;
  final VoidCallback onGithub;
  final VoidCallback onGoogle;

  @override
  Widget build(BuildContext context) {
    final c = context.dpColors;
    final horizontalPadding = context.windowClass == DpWindowClass.compact
        ? DpSpacing.lg
        : DpSpacing.xl;
    return Container(
      key: const ValueKey('login-access-panel'),
      constraints: const BoxConstraints(maxWidth: 480),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const DpPageHeader(
            title: '다시 만나서 반가워요',
            description: '계정을 연결하고 오늘의 학습 흐름을 이어가세요.',
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(DpSpacing.lg),
                    decoration: BoxDecoration(
                      color: c.danger.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(DpRadius.input),
                    ),
                    child: Text(
                      error!,
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: c.danger),
                    ),
                  ),
                  const SizedBox(height: DpSpacing.lg),
                ],
                FilledButton.icon(
                  onPressed: onGithub,
                  icon: const Icon(DpIcons.code),
                  label: Text(useMock ? 'GitHub로 계속하기 (목)' : 'GitHub로 계속하기'),
                ),
                const SizedBox(height: DpSpacing.md),
                OutlinedButton.icon(
                  onPressed: onGoogle,
                  icon: const Icon(Icons.language_rounded),
                  label: Text(useMock ? 'Google로 계속하기 (목)' : 'Google로 계속하기'),
                ),
                const SizedBox(height: DpSpacing.xl),
                Text(
                  '계속하면 Leva의 이용약관과 개인정보 처리방침에 동의하게 됩니다.',
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: c.textFaint),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginStoryPanel extends StatelessWidget {
  const _LoginStoryPanel({required this.themeToggle});

  final Widget themeToggle;

  @override
  Widget build(BuildContext context) {
    final c = context.dpColors;
    final text = Theme.of(context).textTheme;
    return Container(
      key: const ValueKey('login-story-panel'),
      margin: const EdgeInsets.all(DpSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c.accentSoft, c.surfaceMuted],
        ),
        border: Border.all(color: c.accentLine),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -90,
            top: -70,
            child: _DecorativeOrb(color: c.primary.withValues(alpha: 0.14)),
          ),
          Positioned(
            left: -120,
            bottom: -130,
            child: _DecorativeOrb(
              color: c.chart4.withValues(alpha: 0.10),
              size: 300,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(DpSpacing.xxl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                brandRow(context, actions: [themeToggle]),
                const Spacer(),
                Text(
                  '오늘 할 일을 선명하게,',
                  style: text.displaySmall?.copyWith(
                    color: c.textPrimary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1.2,
                  ),
                ),
                const SizedBox(height: DpSpacing.sm),
                Text(
                  '성장은 매일 이어지게.',
                  style: text.displaySmall?.copyWith(
                    color: c.primaryText,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1.2,
                  ),
                ),
                const SizedBox(height: DpSpacing.xl),
                Text(
                  '진단부터 실습, AI 멘토 피드백까지\n하나의 흐름으로 연결합니다.',
                  style: text.bodyLarge?.copyWith(color: c.textSecondary),
                ),
                const SizedBox(height: DpSpacing.xxl),
                const Wrap(
                  spacing: DpSpacing.sm,
                  runSpacing: DpSpacing.sm,
                  children: [
                    _StoryChip(label: '맞춤 학습 경로'),
                    _StoryChip(label: '실시간 AI 멘토'),
                    _StoryChip(label: '성장 기록'),
                  ],
                ),
                const Spacer(),
                Text(
                  'LEARN · BUILD · GROW',
                  style: text.labelMedium?.copyWith(
                    color: c.textFaint,
                    letterSpacing: 1.8,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StoryChip extends StatelessWidget {
  const _StoryChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: DpSpacing.md,
      vertical: DpSpacing.sm,
    ),
    decoration: BoxDecoration(
      color: context.dpColors.surface.withValues(alpha: 0.78),
      border: Border.all(color: context.dpColors.accentLine),
      borderRadius: BorderRadius.circular(DpRadius.chip),
    ),
    child: Text(label, style: Theme.of(context).textTheme.labelMedium),
  );
}

class _DecorativeOrb extends StatelessWidget {
  const _DecorativeOrb({required this.color, this.size = 240});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}
