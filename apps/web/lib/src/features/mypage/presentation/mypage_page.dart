import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/mypage_controller.dart';
import '../state/mypage_state.dart';
import '../../common/application/track_catalog.dart';
import '../../support/presentation/supportable_error.dart';
import '../../mentor/application/mentor_access_controller.dart';
import '../../mentor/state/mentor_access_state.dart';

/// 마이페이지: 프로필 표시/편집 + 활동 집계(부분실패 내성) + 설정 진입.
/// avatar 파일 선택 UI(웹 file picker)는 후속 — controller.uploadAvatar 배선은 완료.
class MyPagePage extends ConsumerStatefulWidget {
  const MyPagePage({super.key});

  @override
  ConsumerState<MyPagePage> createState() => _MyPagePageState();
}

class _MyPagePageState extends ConsumerState<MyPagePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(myPageControllerProvider.notifier).load();
      ref.read(mentorAccessControllerProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(myPageControllerProvider);
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(
            child: DpPageHeader(title: '마이페이지', description: '프로필과 활동 기록입니다'),
          ),
          switch (s) {
            MyPageLoading() => const SliverFillRemaining(
              hasScrollBody: false,
              child: DpLoading(),
            ),
            MyPageFailed(:final message) => SliverFillRemaining(
              hasScrollBody: false,
              child: SupportableError(
                message: message,
                onRetry: () =>
                    ref.read(myPageControllerProvider.notifier).load(),
              ),
            ),
            MyPageLoaded() => _Body(state: s),
          },
        ],
      ),
    );
  }
}

class _Body extends ConsumerStatefulWidget {
  const _Body({required this.state});
  final MyPageLoaded state;

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  /// 서버 enum → 표시 라벨. **키가 전송 payload(`learningGoal`·`targetTrack`)의
  /// 값이고 서버 계약이라 불변**이다. 값(라벨)만 화면 표시용이다.
  static const _goalLabels = <String, String>{
    'JOB': '취업',
    'CAREER_CHANGE': '커리어 전환',
    'UPSKILL': '역량 강화',
    'SIDE_PROJECT': '사이드 프로젝트',
  };

  late final TextEditingController _bio;
  late final TextEditingController _years;
  String? _learningGoal;
  String? _targetTrack;

  @override
  void initState() {
    super.initState();
    final p = widget.state.profile;
    _bio = TextEditingController(text: p.bio ?? '');
    _years = TextEditingController(text: p.experienceYears?.toString() ?? '');
    _learningGoal = _goalLabels.containsKey(p.learningGoal)
        ? p.learningGoal
        : null;
    _targetTrack = trackLabels.containsKey(p.targetTrack)
        ? p.targetTrack
        : null;
  }

  @override
  void dispose() {
    _bio.dispose();
    _years.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    try {
      await ref.read(myPageControllerProvider.notifier).saveProfile({
        'bio': _bio.text,
        'learningGoal': _learningGoal,
        'targetTrack': _targetTrack,
        'experienceYears': int.tryParse(_years.text),
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('저장했습니다')));
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('저장 실패: ${e.message}')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dpColors;
    final text = Theme.of(context).textTheme;
    final st = widget.state;
    final p = st.profile;
    final mentorAccess = ref.watch(mentorAccessControllerProvider);
    final trackLabel = trackLabels[p.targetTrack];
    final goalLabel = _goalLabels[p.learningGoal];
    // 값은 오늘 화면(`today_panels.dart`)과 같은 `DashboardSummary` 를 쓴다.
    // **문구는 다르다** — 그 화면은 키-값으로 「연속 학습 / N일」을 그리고,
    // 여기 배지는 시안 `.prof` 의 `7일 연속` 형태로 합성한다. 요청은 늘지
    // 않는다 — `MyPageLoaded` 가 이미 `dashboard` 를 들고 있다.
    final summary = st.dashboard;
    final badgeLabels = <String>[
      ...?summary?.badges,
      if (summary != null && summary.streakDays > 0)
        '${summary.streakDays}일 연속',
    ];

    return SliverPadding(
      // 좌우 패딩은 셸이 준다 — 화면은 위아래만 준다.
      padding: const EdgeInsets.symmetric(vertical: DpSpacing.md),
      sliver: SliverToBoxAdapter(
        child: DpCols(
          main: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 시안 `.prof` — 패널이 아니다(배경·테두리 없음). 아바타 + 소개 + 배지.
              Row(
                key: const ValueKey('mypage-prof'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundImage: p.avatar != null
                        ? NetworkImage(p.avatar!)
                        : null,
                    child: p.avatar == null
                        ? const Icon(Icons.account_circle, size: 48)
                        : null,
                  ),
                  const SizedBox(width: DpSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          (p.bio?.isNotEmpty ?? false) ? p.bio! : '소개가 아직 없어요',
                          key: const ValueKey('mypage-prof-bio'),
                          // 편집 폼의 maxLength 가 500 이다 — 줄 수를 묶지 않으면
                          // 긴 소개가 머리에서 아래 폼을 밀어낸다.
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleMedium?.copyWith(
                            color: (p.bio?.isNotEmpty ?? false)
                                ? c.textPrimary
                                : c.textSecondary,
                          ),
                        ),
                        const SizedBox(height: DpSpacing.xs),
                        // `CircleAvatar` 에는 시맨틱스 라벨이 없다 — 이 문구가
                        // 없으면 사진 유무를 알 방법이 사라진다.
                        Text(
                          p.avatar == null ? '프로필 사진 없음' : '프로필 사진',
                          style: text.bodySmall?.copyWith(
                            color: c.textSecondary,
                          ),
                        ),
                        if (badgeLabels.isNotEmpty) ...[
                          const SizedBox(height: DpSpacing.sm),
                          Wrap(
                            key: const ValueKey('mypage-prof-badges'),
                            spacing: DpSpacing.sm,
                            runSpacing: DpSpacing.sm,
                            children: [
                              for (final b in badgeLabels) DpTag(label: b),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: DpSpacing.xl),
              DpPanel(
                title: const DpPanelTitle('프로필 편집'),
                padding: const EdgeInsets.all(DpSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _bio,
                      maxLines: 3,
                      maxLength: 500,
                      decoration: const InputDecoration(labelText: '자기소개'),
                    ),
                    const SizedBox(height: DpSpacing.sm),
                    DropdownButtonFormField<String>(
                      initialValue: _learningGoal,
                      decoration: const InputDecoration(labelText: '학습 목표'),
                      items: [
                        for (final e in _goalLabels.entries)
                          DropdownMenuItem(value: e.key, child: Text(e.value)),
                      ],
                      onChanged: (v) => setState(() => _learningGoal = v),
                    ),
                    const SizedBox(height: DpSpacing.sm),
                    DropdownButtonFormField<String>(
                      initialValue: _targetTrack,
                      decoration: const InputDecoration(labelText: '목표 트랙'),
                      items: [
                        for (final e in trackLabels.entries)
                          DropdownMenuItem(value: e.key, child: Text(e.value)),
                      ],
                      onChanged: (v) => setState(() => _targetTrack = v),
                    ),
                    const SizedBox(height: DpSpacing.sm),
                    TextField(
                      controller: _years,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '경력(년)'),
                    ),
                    const SizedBox(height: DpSpacing.md),
                    FilledButton(
                      onPressed: st.saving ? null : _save,
                      child: Text(st.saving ? '저장 중...' : '저장'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: DpSpacing.lg),
              // 활동은 집계 두 줄이다 — 시안의 활동 표를 만들 목록 데이터가 없다.
              DpPanel(
                title: const DpPanelTitle('활동'),
                padding: const EdgeInsets.all(DpSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (st.dashboard != null)
                      Text('완료한 콘텐츠 ${st.dashboard!.completedContentCount}개')
                    else
                      Text(
                        '학습 활동을 불러오지 못했습니다',
                        style: text.bodySmall?.copyWith(color: c.textSecondary),
                      ),
                    const SizedBox(height: DpSpacing.xs),
                    if (st.activity != null)
                      Text(
                        '작성한 질문 ${st.activity!.questionCount} · 답변 ${st.activity!.answerCount}',
                      )
                    else
                      Text(
                        '커뮤니티 활동을 불러오지 못했습니다',
                        style: text.bodySmall?.copyWith(color: c.textSecondary),
                      ),
                  ],
                ),
              ),
            ],
          ),
          side: DpSide(
            children: [
              if (trackLabel != null ||
                  goalLabel != null ||
                  p.experienceYears != null)
                DpPanel(
                  key: const ValueKey('mypage-profile-kv'),
                  title: const DpPanelTitle('프로필'),
                  // 시안 사이드 `.kv`: 목표 트랙 · 목표 · 경력(년).
                  //
                  // **남은 divergence**: 시안의 마이페이지에는 편집 폼이 없다
                  // (헤더의 `프로필 편집` 버튼으로 빠진다). 이 화면은 편집을
                  // 인라인으로 두므로 같은 세 값이 아래 「프로필 편집」 패널에도
                  // 나온다. 편집을 별도 라우트로 빼는 것은 S3-P5 범위 밖이다.
                  child: DpKeyValues(
                    entries: [
                      if (trackLabel != null)
                        (key: '목표 트랙', value: Text(trackLabel)),
                      if (goalLabel != null)
                        (key: '목표', value: Text(goalLabel)),
                      if (p.experienceYears != null)
                        (key: '경력(년)', value: Text('${p.experienceYears}')),
                    ],
                  ),
                ),
              DpPanel(
                title: const DpPanelTitle('AI 멘토 초대'),
                padding: const EdgeInsets.all(DpSpacing.lg),
                child: switch (mentorAccess) {
                  MentorAccessLoading() => const Text('초대 상태를 확인하는 중입니다.'),
                  MentorAccessFailed() => const Text('초대 상태를 불러오지 못했습니다.'),
                  MentorAccessReady(:final isActive) => Text(
                    isActive
                        ? 'AI 멘토를 사용할 수 있습니다.'
                        : '초대 대기 중입니다. 담당자가 확인 후 초대 일정을 이메일로 안내해 드립니다.',
                  ),
                },
              ),
              DpPanel(
                child: DpRowLine(
                  label: const Text('설정'),
                  description: const Text('알림·동의·계정을 관리합니다.'),
                  trailing: DpLink.inline(
                    text: '열기',
                    semanticsLabel: '설정 열기',
                    onTap: () => context.go('/settings'),
                  ),
                  last: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
