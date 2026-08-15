import 'dart:async';
import 'dart:convert';

import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/application/auth_controller.dart';
import '../../auth/state/auth_state.dart';
import '../../common/application/track_catalog.dart';
import '../../common/presentation/brand_row.dart';
import '../../../providers/api_providers.dart';
import '../application/diagnostic_controller.dart';
import '../state/diagnostic_continuation.dart';
import '../state/diagnostic_state.dart';

class DiagnosticPage extends ConsumerStatefulWidget {
  const DiagnosticPage({super.key});

  @override
  ConsumerState<DiagnosticPage> createState() => _DiagnosticPageState();
}

class _DiagnosticPageState extends ConsumerState<DiagnosticPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(ref.read(diagnosticControllerProvider.notifier).resume());
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(diagnosticControllerProvider);
    final notifier = ref.read(diagnosticControllerProvider.notifier);
    final auth = ref.watch(authControllerProvider);
    final missionSpineEnabled = ref.watch(
      appConfigProvider.select((config) => config.missionSpineEnabled),
    );

    // OAuth/bootstrap과 consent 갱신은 route refresh와 동시에 올 수 있다.
    // controller의 claim single-flight가 callback/rebuild 중복을 흡수한다.
    ref.listen(authControllerProvider, (_, _) {
      unawaited(notifier.resume());
    });

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: context.appTokens.readableMaxWidth,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                brandRow(context),
                DpPageHeader(
                  title: '실력 진단',
                  description: missionSpineEnabled
                      ? '15문항으로 현재 수준과 다음 학습 출발점을 확인합니다'
                      : '몇 문항으로 현재 수준을 파악합니다',
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    DpSpacing.xl,
                    0,
                    DpSpacing.xl,
                    DpSpacing.xl,
                  ),
                  child: missionSpineEnabled
                      ? _body(context, state, notifier, auth)
                      : _legacyBody(context, state, notifier, auth),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    DiagnosticState state,
    DiagnosticController notifier,
    AuthState auth,
  ) {
    if (state.hasPreview) {
      return _ResultPreview(state: state, notifier: notifier);
    }

    final failure = state.failure;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (failure != null) ...[
          _FailureBanner(failure: failure),
          const SizedBox(height: DpSpacing.lg),
        ],
        if (state.phase == DiagnosticContinuationPhase.questions)
          if (state.nextQuestion case final next?)
            _QuestionView(
              next: next,
              notifier: notifier,
              busy: state.busy,
              answerFailed: failure?.kind == DiagnosticFailureKind.answer,
              advanceFailed: failure?.kind == DiagnosticFailureKind.initialLoad,
              pendingAnswer: state.pendingAnswer,
              missionSpineEnabled: true,
            )
          else if (failure?.kind == DiagnosticFailureKind.initialLoad)
            _AdvanceRetry(notifier: notifier, busy: state.busy)
          else
            const _StageLoading(label: '다음 문항을 불러오고 있어요')
        else if (state.busy)
          const _StageLoading(label: '진단을 준비하고 있어요')
        else
          _StartView(
            state: state,
            auth: auth,
            notifier: notifier,
            missionSpineEnabled: true,
          ),
      ],
    );
  }

  Widget _legacyBody(
    BuildContext context,
    DiagnosticState state,
    DiagnosticController notifier,
    AuthState auth,
  ) {
    if (state.hasPreview) {
      return _LegacyPreview(state: state, notifier: notifier, auth: auth);
    }
    final failure = state.failure;
    if (state.phase == DiagnosticContinuationPhase.questions) {
      if (state.nextQuestion case final next?) {
        return _QuestionView(
          next: next,
          notifier: notifier,
          busy: state.busy,
          answerFailed: failure?.kind == DiagnosticFailureKind.answer,
          advanceFailed: failure?.kind == DiagnosticFailureKind.initialLoad,
          pendingAnswer: state.pendingAnswer,
          missionSpineEnabled: false,
        );
      }
      if (failure?.kind == DiagnosticFailureKind.initialLoad) {
        return _AdvanceRetry(notifier: notifier, busy: state.busy);
      }
      return const _StageLoading(label: '다음 문항을 불러오고 있어요');
    }
    if (state.busy) return const _StageLoading(label: '진단을 준비하고 있어요');
    if (failure != null) return _FailureBanner(failure: failure);
    return _StartView(
      state: state,
      auth: auth,
      notifier: notifier,
      missionSpineEnabled: false,
    );
  }
}

class _StartView extends StatelessWidget {
  const _StartView({
    required this.state,
    required this.auth,
    required this.notifier,
    required this.missionSpineEnabled,
  });

  final DiagnosticState state;
  final AuthState auth;
  final DiagnosticController notifier;
  final bool missionSpineEnabled;

  @override
  Widget build(BuildContext context) {
    final selectedTrack = state.track;
    final isMember = auth is AuthAuthenticated;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('실력 진단 15문항', style: Theme.of(context).textTheme.titleMedium),
        if (missionSpineEnabled) ...[
          const SizedBox(height: DpSpacing.sm),
          Text(
            '로그인 없이 시작하고, 완료하면 현재 레벨과 신뢰도를 먼저 확인할 수 있어요.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.dpColors.textSecondary,
            ),
          ),
        ],
        const SizedBox(height: DpSpacing.lg),
        DropdownButtonFormField<String>(
          key: const ValueKey('diagnostic-track'),
          initialValue: selectedTrack,
          decoration: const InputDecoration(labelText: '진단할 트랙'),
          items: [
            for (final entry in trackLabels.entries)
              DropdownMenuItem(value: entry.key, child: Text(entry.value)),
          ],
          onChanged: (value) {
            if (value != null) notifier.selectTrack(value);
          },
        ),
        if (selectedTrack == null) ...[
          const SizedBox(height: DpSpacing.sm),
          Text(
            '트랙을 먼저 골라주세요. 고른 트랙이 문항과 이후 경로의 기준이 됩니다.',
            key: const ValueKey('diagnostic-track-hint'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: DpSpacing.lg),
        FilledButton(
          onPressed: selectedTrack == null
              ? null
              : () => isMember
                    ? notifier.startAsMember(selectedTrack)
                    : notifier.startAsGuest(selectedTrack),
          child: const Text('진단 시작하기'),
        ),
      ],
    );
  }
}

class _QuestionView extends StatelessWidget {
  const _QuestionView({
    required this.next,
    required this.notifier,
    required this.busy,
    required this.answerFailed,
    required this.advanceFailed,
    required this.pendingAnswer,
    required this.missionSpineEnabled,
  });

  final NextQuestion next;
  final DiagnosticController notifier;
  final bool busy;
  final bool answerFailed;
  final bool advanceFailed;
  final String? pendingAnswer;
  final bool missionSpineEnabled;

  List<String> _options(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) return decoded.map((value) => '$value').toList();
    } catch (_) {}
    return const [];
  }

  int? _selectedOptionIndex() {
    final raw = pendingAnswer;
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic> && decoded['correct'] is int) {
        return decoded['correct'] as int;
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final question = next.question;
    final options = _options(question.options);
    final selectedOptionIndex = _selectedOptionIndex();
    final progress = next.total <= 0
        ? 0.0
        : (next.index / next.total).clamp(0.0, 1.0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          missionSpineEnabled
              ? '${next.index} / ${next.total} · ${next.total - next.index}문항 남음'
              : '${next.index} / ${next.total} · 진단',
          style: Theme.of(context).textTheme.labelMedium,
        ),
        if (missionSpineEnabled) ...[
          const SizedBox(height: DpSpacing.sm),
          LinearProgressIndicator(value: progress),
        ],
        const SizedBox(height: DpSpacing.lg),
        Text(question.content, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: DpSpacing.lg),
        if (answerFailed) ...[
          Text(
            '답변이 저장되지 않았어요. 현재 문항과 선택은 그대로예요.',
            style: TextStyle(color: context.dpColors.danger),
          ),
          const SizedBox(height: DpSpacing.sm),
          FilledButton(
            onPressed: busy ? null : notifier.retryLastAnswer,
            child: const Text('같은 답변 다시 저장'),
          ),
          const SizedBox(height: DpSpacing.md),
        ],
        if (advanceFailed) ...[
          FilledButton(
            onPressed: busy ? null : notifier.retryAdvance,
            child: const Text('다음 문항 다시 불러오기'),
          ),
          const SizedBox(height: DpSpacing.md),
        ] else if (options.isEmpty)
          FilledButton(
            onPressed: busy || answerFailed
                ? null
                : () => notifier.submitAnswer(
                    question.id,
                    '{"correct":0}',
                    timeSpentSec: 5,
                  ),
            child: const Text('답안 제출'),
          )
        else
          for (var index = 0; index < options.length; index++) ...[
            OutlinedButton(
              key: answerFailed && selectedOptionIndex == index
                  ? ValueKey('diagnostic-option-selected-$index')
                  : ValueKey('diagnostic-option-$index'),
              onPressed: busy || answerFailed
                  ? null
                  : () => notifier.submitAnswer(
                      question.id,
                      '{"correct":$index}',
                      timeSpentSec: 5,
                    ),
              child: Text(
                answerFailed && selectedOptionIndex == index
                    ? '✓ ${options[index]}'
                    : options[index],
              ),
            ),
            const SizedBox(height: DpSpacing.sm),
          ],
        if (!advanceFailed && !answerFailed) ...[
          const SizedBox(height: DpSpacing.md),
          const Divider(),
          TextButton(
            onPressed: busy ? null : () => notifier.skip(question.id),
            child: const Text('잘 모르겠어요'),
          ),
        ],
      ],
    );
  }
}

class _AdvanceRetry extends StatelessWidget {
  const _AdvanceRetry({required this.notifier, required this.busy});

  final DiagnosticController notifier;
  final bool busy;

  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: busy ? null : notifier.retryAdvance,
    child: const Text('다음 문항 다시 불러오기'),
  );
}

class _LegacyPreview extends StatelessWidget {
  const _LegacyPreview({
    required this.state,
    required this.notifier,
    required this.auth,
  });

  final DiagnosticState state;
  final DiagnosticController notifier;
  final AuthState auth;

  @override
  Widget build(BuildContext context) {
    final failure = state.failure;
    if (failure?.kind == DiagnosticFailureKind.guestExpired ||
        failure?.kind == DiagnosticFailureKind.ownership) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _FailureBanner(failure: failure!),
          const SizedBox(height: DpSpacing.lg),
          FilledButton(
            onPressed: notifier.restart,
            child: const Text('새 진단 시작'),
          ),
        ],
      );
    }
    if (auth is! AuthAuthenticated && !state.saved) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (failure != null) ...[
            _FailureBanner(failure: failure),
            const SizedBox(height: DpSpacing.lg),
          ],
          Text(
            '결과를 보려면 로그인하세요',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: DpSpacing.lg),
          FilledButton(
            onPressed: state.busy ? null : notifier.saveAndContinue,
            child: const Text('GitHub로 로그인'),
          ),
        ],
      );
    }
    if (failure != null) {
      final pathFailure = failure.kind == DiagnosticFailureKind.pathGeneration;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _FailureBanner(failure: failure),
          const SizedBox(height: DpSpacing.lg),
          FilledButton(
            onPressed: state.busy
                ? null
                : pathFailure
                ? notifier.retryPathProbe
                : notifier.saveAndContinue,
            child: Text(pathFailure ? '경로 상태 다시 확인' : '저장 다시 시도'),
          ),
        ],
      );
    }
    return const _StageLoading(label: '결과를 계정에 연결하고 있어요');
  }
}

class _ResultPreview extends StatelessWidget {
  const _ResultPreview({required this.state, required this.notifier});

  final DiagnosticState state;
  final DiagnosticController notifier;

  @override
  Widget build(BuildContext context) {
    final preview = state.preview!;
    final confidence = preview.confidenceWeight == null
        ? '계산 중'
        : '${(preview.confidenceWeight! * 100).round()}%';
    final track = trackLabels[state.track] ?? state.track ?? '선택한 트랙';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('진단 결과', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: DpSpacing.sm),
        Text(
          state.saved ? '계정에 안전하게 저장됐어요.' : '로그인 전에 결과를 먼저 확인하세요.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: context.dpColors.textSecondary,
          ),
        ),
        const SizedBox(height: DpSpacing.lg),
        Container(
          padding: const EdgeInsets.all(DpSpacing.lg),
          decoration: BoxDecoration(
            color: context.dpColors.surface,
            border: Border.all(color: context.dpColors.border),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(track, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: DpSpacing.sm),
              Text(
                '현재 레벨 ${preview.diagnosedLevel}',
                key: const ValueKey('diagnostic-preview-level'),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: DpSpacing.xs),
              Text(
                '진단 신뢰도 $confidence',
                key: const ValueKey('diagnostic-preview-confidence'),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        const SizedBox(height: DpSpacing.md),
        Container(
          padding: const EdgeInsets.all(DpSpacing.md),
          decoration: BoxDecoration(
            color: context.dpColors.surfaceMuted,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('결과 형태 미리보기'),
              SizedBox(height: DpSpacing.xs),
              Text('저장 후 이 결과를 기준으로 첫 주 경로와 오늘의 미션을 구성합니다.'),
            ],
          ),
        ),
        if (state.pathBranch == DiagnosticPathBranch.existingActivePath) ...[
          const SizedBox(height: DpSpacing.md),
          const Text('기존 학습 경로는 바꾸지 않았어요. 지금 하던 경로를 그대로 이어갑니다.'),
        ],
        if (state.failure case final failure?) ...[
          const SizedBox(height: DpSpacing.md),
          _FailureBanner(failure: failure),
        ],
        const SizedBox(height: DpSpacing.xl),
        _primaryAction(context),
        if (!state.busy &&
            !state.saved &&
            state.failure?.kind != DiagnosticFailureKind.guestExpired &&
            state.failure?.kind != DiagnosticFailureKind.ownership) ...[
          const SizedBox(height: DpSpacing.sm),
          TextButton(
            onPressed: notifier.restart,
            child: const Text('진단 다시 시작'),
          ),
        ],
      ],
    );
  }

  Widget _primaryAction(BuildContext context) {
    final failureKind = state.failure?.kind;
    if (failureKind == DiagnosticFailureKind.pathGeneration) {
      return FilledButton(
        onPressed: state.busy ? null : notifier.retryPathProbe,
        child: const Text('경로 상태 다시 확인'),
      );
    }
    if (failureKind == DiagnosticFailureKind.guestExpired ||
        failureKind == DiagnosticFailureKind.ownership) {
      return FilledButton(
        onPressed: notifier.restart,
        child: const Text('새 진단 시작'),
      );
    }
    if (state.saved) {
      if (state.pathBranch == DiagnosticPathBranch.unknown) {
        return FilledButton(
          onPressed: null,
          child: Text(state.busy ? '경로 확인 중' : '경로 상태 확인 필요'),
        );
      }
      final existing =
          state.pathBranch == DiagnosticPathBranch.existingActivePath;
      return FilledButton(
        onPressed: state.busy
            ? null
            : () {
                notifier.completePathHandoff();
                context.go('/path');
              },
        child: Text(existing ? '기존 경로로 계속' : '학습 경로로 계속'),
      );
    }
    if (state.phase == DiagnosticContinuationPhase.consent) {
      return FilledButton(
        onPressed: state.busy ? null : () => context.go('/consent'),
        child: const Text('필수 동의 확인'),
      );
    }
    return FilledButton(
      onPressed: state.busy ? null : notifier.saveAndContinue,
      child: Text(
        state.busy
            ? '결과 저장 중'
            : failureKind == DiagnosticFailureKind.claim ||
                  failureKind == DiagnosticFailureKind.resultMismatch
            ? '저장 다시 시도'
            : '저장하고 계속',
      ),
    );
  }
}

class _FailureBanner extends StatelessWidget {
  const _FailureBanner({required this.failure});

  final DiagnosticFailure failure;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      padding: const EdgeInsets.all(DpSpacing.md),
      decoration: BoxDecoration(
        color: context.dpColors.danger.withValues(alpha: 0.08),
        border: Border.all(
          color: context.dpColors.danger.withValues(alpha: 0.35),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        failure.message,
        style: TextStyle(color: context.dpColors.danger),
      ),
    ),
  );
}

class _StageLoading extends StatelessWidget {
  const _StageLoading({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const CircularProgressIndicator(),
      const SizedBox(height: DpSpacing.md),
      Text(label),
    ],
  );
}
