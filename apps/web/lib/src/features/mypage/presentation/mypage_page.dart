import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/mypage_controller.dart';
import '../state/mypage_state.dart';
import '../../support/presentation/supportable_error.dart';

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
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(myPageControllerProvider.notifier).load(),
    );
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

  static const _trackLabels = <String, String>{
    'BACKEND_SPRING': '백엔드 (Spring)',
    'FRONTEND_REACT': '프론트엔드 (React)',
    'MOBILE_FLUTTER': '모바일 (Flutter)',
    'DEVOPS': 'DevOps',
    'FULLSTACK': '풀스택',
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
    _targetTrack = _trackLabels.containsKey(p.targetTrack)
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

    Widget card(Widget child) => Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: DpSpacing.md),
      padding: const EdgeInsets.all(DpSpacing.lg),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(DpRadius.card),
      ),
      child: child,
    );

    return SliverPadding(
      padding: const EdgeInsets.all(DpSpacing.lg),
      sliver: SliverList.list(
        children: [
          // 프로필 헤더(avatar 또는 기본 아이콘)
          card(
            Row(
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
                const SizedBox(width: DpSpacing.md),
                Expanded(
                  child: Text(
                    p.avatar == null ? '프로필 사진 없음' : '프로필 사진',
                    style: text.bodyMedium?.copyWith(color: c.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          // 프로필 편집 폼
          card(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('프로필 편집', style: text.titleMedium),
                const SizedBox(height: DpSpacing.md),
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
                    for (final e in _trackLabels.entries)
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
          // 활동 요약(부분실패 내성)
          card(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('활동', style: text.titleMedium),
                const SizedBox(height: DpSpacing.sm),
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
          // 설정 진입
          card(
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.settings_outlined),
              title: const Text('설정'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/settings'),
            ),
          ),
        ],
      ),
    );
  }
}
