import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/settings_controller.dart';
import '../data/settings_models.dart';
import '../state/settings_state.dart';

/// 동의 타입 → 표시 라벨 + 필수 여부. 백엔드 ConsentType 문자열 기준.
const Map<String, ({String label, bool required})> _consentMeta = {
  'TERMS': (label: '서비스 이용약관', required: true),
  'PRIVACY': (label: '개인정보 수집·이용', required: true),
  'MARKETING': (label: '마케팅 정보 수신', required: false),
  'LCS_ATTACH': (label: '학습 맥락 자동 첨부', required: false),
  'ERROR_LOG': (label: '오류 진단 로그 수집', required: false),
};

/// 설정 화면: 동의 관리(철회)·알림 설정·로그아웃·계정 삭제.
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(settingsControllerProvider.notifier).load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(settingsControllerProvider);
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(
            child: DpPageHeader(title: '설정', description: '알림·동의·계정을 관리합니다'),
          ),
          switch (state) {
            SettingsLoading() => const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            ),
            SettingsError(:final message) => SliverFillRemaining(
              hasScrollBody: false,
              child: _errorView(message),
            ),
            SettingsReady(:final consents, :final prefs) => _readyView(
              consents,
              prefs,
            ),
          },
        ],
      ),
    );
  }

  Widget _errorView(String message) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message),
        const SizedBox(height: DpSpacing.md),
        FilledButton(
          onPressed: () => ref.read(settingsControllerProvider.notifier).load(),
          child: const Text('다시 시도'),
        ),
      ],
    ),
  );

  Widget _readyView(ConsentsView consents, NotificationPrefs prefs) {
    final notifier = ref.read(settingsControllerProvider.notifier);
    return SliverPadding(
      padding: const EdgeInsets.symmetric(vertical: DpSpacing.md),
      sliver: SliverList.list(
        children: [
          _header('동의 관리'),
          for (final type in _consentMeta.keys)
            _consentTile(type, consents.itemOf(type), notifier),
          const Divider(),
          _header('알림'),
          SwitchListTile(
            title: const Text('학습 리마인더'),
            subtitle: const Text('선호 시간대에 학습 알림을 받아요.'),
            value: prefs.reminderEnabled,
            onChanged: notifier.setReminder,
          ),
          SwitchListTile(
            title: const Text('주간 리포트 이메일'),
            subtitle: const Text('한 주 학습 요약을 이메일로 받아요.'),
            value: prefs.weeklyReportEmailEnabled,
            onChanged: notifier.setWeeklyEmail,
          ),
          const Divider(),
          _header('계정'),
          ListTile(title: const Text('로그아웃'), onTap: () => notifier.logout()),
          ListTile(
            title: Text(
              '계정 삭제',
              style: TextStyle(color: context.dpColors.danger),
            ),
            subtitle: const Text('계정과 학습 데이터가 삭제됩니다(30일 유예).'),
            onTap: _confirmDelete,
          ),
        ],
      ),
    );
  }

  Widget _header(String title) => Padding(
    padding: const EdgeInsets.fromLTRB(
      DpSpacing.lg,
      DpSpacing.md,
      DpSpacing.lg,
      DpSpacing.xs,
    ),
    child: Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleSmall?.copyWith(color: context.dpColors.textSecondary),
    ),
  );

  Widget _consentTile(
    String type,
    ConsentItemView? item,
    SettingsController notifier,
  ) {
    final meta = _consentMeta[type]!;
    final agreed = item?.agreed ?? false;
    if (meta.required) {
      return ListTile(
        title: Text(meta.label),
        subtitle: const Text('필수'),
        trailing: Icon(DpIcons.stepDone, color: context.dpColors.success),
      );
    }
    // 선택 동의: 현재 동의된 항목만 철회 가능(재동의는 후속).
    return SwitchListTile(
      title: Text(meta.label),
      subtitle: const Text('선택'),
      value: agreed,
      onChanged: agreed
          ? (v) {
              if (!v) notifier.revokeConsent(type);
            }
          : null,
    );
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('계정을 삭제할까요?'),
        content: const Text(
          '계정과 학습 데이터가 삭제되며 30일 후 완전히 파기됩니다. 이 작업은 되돌릴 수 없어요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(settingsControllerProvider.notifier).deleteAccount();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('계정 삭제에 실패했어요. 다시 시도해 주세요.')),
      );
    }
  }
}
