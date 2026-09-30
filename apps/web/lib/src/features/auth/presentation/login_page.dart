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
///
/// 시안 `login` — `.login{grid-template-columns:minmax(0,1.1fr) minmax(0,.9fr);
/// gap:48px}`. 좌측은 `.flow` 목록 3항목, 우측은 `.panel.signin` 이다.
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
    final access = auth is AuthLoading
        ? const _LoginSessionCheck()
        : _LoginAccessPanel(
            error: error,
            useMock: useMock,
            onGithub: () => useMock
                ? ref
                      .read(authControllerProvider.notifier)
                      .bootstrapFromCallback()
                : ref.read(authControllerProvider.notifier).login(),
            onGoogle: () => useMock
                ? ref
                      .read(authControllerProvider.notifier)
                      .bootstrapFromCallback()
                : ref
                      .read(authControllerProvider.notifier)
                      .login(provider: 'google'),
          );

    // 폭 경계의 SSoT 는 `DpWindowClass` 다 — 옛 리터럴 900 은 어느 토큰과도
    // 맞지 않았다. `.login` 은 시안 `@container(max-width:720px)` 에 해당하므로
    // medium 이하에서 한 열로 간다(`DpCols` 와 같은 판정).
    final windowClass = context.windowClass;
    final twoColumn = switch (windowClass) {
      DpWindowClass.expanded || DpWindowClass.large => true,
      DpWindowClass.compact || DpWindowClass.medium => false,
    };
    // compact 은 스토리를 접는다 — 폰에서는 로그인 한 흐름만 남긴다(기존 동작).
    final showStory = windowClass != DpWindowClass.compact;

    // 로그인은 셸 밖(bare 라우트)이라 거터를 줄 셸이 없다. 페이지가 스스로 준다.
    final gutter = windowClass == DpWindowClass.compact
        ? DpSpacing.lg
        : DpSpacing.xl;

    final layout = twoColumn
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Expanded(flex: 11, child: _LoginStory()),
              const SizedBox(width: DpSpacing.xxxl),
              Expanded(flex: 9, child: access),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showStory) ...[
                const _LoginStory(),
                const SizedBox(height: DpSpacing.xl),
              ],
              // 1열에서도 패널이 한없이 넓어지지 않게 읽기 폭으로 묶는다
              // (medium 상단 839px 에서 791px 까지 늘어났다).
              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: context.appTokens.readableMaxWidth,
                  ),
                  child: access,
                ),
              ),
            ],
          );

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              brandRow(context, actions: [themeToggle]),
              const SizedBox(height: DpSpacing.xxl),
              // 셸 밖 bare 라우트라 본문 폭을 줄 셸이 없다 — 화면이 직접 캡을 둔다.
              // 없으면 1920px 에서 로그인 버튼이 820px 로 늘어난다.
              Center(
                child: ConstrainedBox(
                  key: const ValueKey('login-content'),
                  constraints: BoxConstraints(
                    maxWidth: context.appTokens.contentMaxWidth,
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: gutter),
                    child: layout,
                  ),
                ),
              ),
              const SizedBox(height: DpSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }
}

/// 시안 `.login` 좌측 — eyebrow + 큰 제목 + 설명 + `.flow` 목록 3항목.
/// 장식(그라디언트 배경·원)을 쓰지 않는다 — 시안의 면 구분은 1px 테두리뿐이다.
class _LoginStory extends StatelessWidget {
  const _LoginStory();

  static const _flow = <({String title, String body})>[
    (title: '맞춤 학습 경로', body: '15문항 진단과 GitHub 분석으로 12주 계획을 만듭니다.'),
    (title: '실시간 AI 멘토', body: '지금 보고 있는 과제의 맥락으로 답합니다.'),
    (title: '성장 기록', body: '완료한 과제와 연속 학습이 쌓입니다.'),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.dpColors;
    final text = Theme.of(context).textTheme;
    return Column(
      key: const ValueKey('login-story'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'LEARN · BUILD · GROW',
          style: text.labelMedium?.copyWith(
            color: c.primaryTextStrong,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: DpSpacing.sm),
        Text(
          '오늘 할 일을 선명하게, 성장은 매일 이어지게.',
          style: text.headlineMedium?.copyWith(color: c.textPrimary),
        ),
        const SizedBox(height: DpSpacing.md),
        Text(
          '진단부터 실습, AI 멘토 피드백까지 하나의 흐름으로 연결합니다.',
          style: text.bodyLarge?.copyWith(color: c.textSecondary),
        ),
        const SizedBox(height: DpSpacing.xl),
        // 시안 `.flow` — 구분선으로 나뉜 3항목.
        DpListLines(
          children: [
            for (final item in _flow)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 시안 `.flow li{grid-template-columns:120px 1fr}` 그대로다.
                  SizedBox(
                    width: 120,
                    child: Text(
                      item.title,
                      style: text.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: c.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: DpSpacing.md),
                  Expanded(
                    child: Text(
                      item.body,
                      style: text.bodyMedium?.copyWith(color: c.textSecondary),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

/// 세션 확인 중 — 시안 `beta` 파생(`.narrow.center`).
class _LoginSessionCheck extends StatelessWidget {
  const _LoginSessionCheck();

  @override
  Widget build(BuildContext context) => Center(
    key: const ValueKey('login-session-check'),
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: context.appTokens.readableMaxWidth),
      child: const Padding(
        padding: EdgeInsets.all(DpSpacing.xl),
        child: DpLoading(label: '세션을 확인하는 중'),
      ),
    ),
  );
}

/// 시안 `.panel.signin` — 패널 제목(h3) + 설명 + 버튼 둘 + 약관 문구.
/// 페이지 헤더가 아니라 패널 제목이므로 `DpPageHeader` 를 쓰지 않는다.
/// 폭은 `.login` 그리드가 정한다 — 480 고정 제약을 두지 않는다.
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
    final text = Theme.of(context).textTheme;
    return DpPanel(
      key: const ValueKey('login-access-panel'),
      padding: const EdgeInsets.all(DpSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('다시 만나서 반가워요', style: text.titleLarge),
          const SizedBox(height: DpSpacing.sm),
          Text(
            '계정을 연결하고 오늘의 학습 흐름을 이어가세요.',
            style: text.bodyMedium?.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: DpSpacing.lg),
          if (error != null) ...[
            DpInlineNotice(message: error!),
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
            style: text.bodySmall?.copyWith(color: c.textSecondary),
          ),
        ],
      ),
    );
  }
}
