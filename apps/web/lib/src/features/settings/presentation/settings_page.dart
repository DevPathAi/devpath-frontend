import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../support/presentation/supportable_error.dart';
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

/// 서버가 보내는 ISO-8601 문자열을 읽히는 날짜로 바꾼다.
///
/// 해석할 수 없으면 null 을 돌려 설명 줄을 생략한다 — 원시 타임스탬프
/// (`2026-07-01T09:00:00Z`)를 사용자 문구로 내보내지 않는다. 표시는 현지 시각
/// 기준이다(동의한 시점을 사용자의 달력으로 읽는 것이 맞다).
String? _agreedAtLabel(String? raw) {
  if (raw == null) return null;
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return null;
  final at = parsed.toLocal();
  final month = at.month.toString().padLeft(2, '0');
  final day = at.day.toString().padLeft(2, '0');
  return '${at.year}.$month.$day 동의';
}

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
              child: DpLoading(label: '설정을 불러오는 중'),
            ),
            SettingsError(:final message) => SliverFillRemaining(
              hasScrollBody: false,
              child: SupportableError(
                message: message,
                onRetry: () =>
                    ref.read(settingsControllerProvider.notifier).load(),
              ),
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

  Widget _readyView(ConsentsView consents, NotificationPrefs prefs) {
    final notifier = ref.read(settingsControllerProvider.notifier);
    final c = context.dpColors;

    return SliverPadding(
      // 좌우 패딩은 셸이 준다 — 화면은 위아래만 준다.
      padding: const EdgeInsets.symmetric(vertical: DpSpacing.md),
      sliver: SliverToBoxAdapter(
        child: Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            // 시안 `settings` 는 `.narrow{max-width:760px;margin-inline:0}` 이다.
            constraints: BoxConstraints(
              maxWidth: context.appTokens.readableMaxWidth,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 시안 순서: 알림 → 동의 관리 → 계정.
                DpPanel(
                  title: const DpPanelTitle('알림'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DpRowLine(
                        label: const Text('학습 리마인더'),
                        description: const Text('선호 시간대에 학습 알림을 받아요.'),
                        trailing: Switch(
                          value: prefs.reminderEnabled,
                          onChanged: notifier.setReminder,
                        ),
                      ),
                      DpRowLine(
                        label: const Text('주간 리포트 이메일'),
                        description: const Text('한 주 학습 요약을 이메일로 받아요.'),
                        trailing: Switch(
                          value: prefs.weeklyReportEmailEnabled,
                          onChanged: notifier.setWeeklyEmail,
                        ),
                        last: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: DpSpacing.lg),
                DpPanel(
                  title: const DpPanelTitle('동의 관리'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final type in _consentMeta.keys)
                        _consentRow(
                          type,
                          consents.itemOf(type),
                          notifier,
                          last: type == _consentMeta.keys.last,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: DpSpacing.lg),
                DpPanel(
                  title: const DpPanelTitle('계정'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DpRowLine(
                        label: const Text('로그아웃'),
                        description: const Text('이 브라우저에서만 로그아웃합니다.'),
                        trailing: OutlinedButton(
                          onPressed: notifier.logout,
                          child: const Text('로그아웃'),
                        ),
                      ),
                      DpRowLine(
                        label: Text('계정 삭제', style: TextStyle(color: c.danger)),
                        description: const Text('계정과 학습 데이터가 삭제됩니다(30일 유예).'),
                        trailing: OutlinedButton(
                          onPressed: _confirmDelete,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: c.danger,
                            side: BorderSide(color: c.danger),
                          ),
                          child: const Text('계정 삭제'),
                        ),
                        last: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 시안 `.rowline` 한 행 — 좌측 라벨·설명, 우측 컨트롤.
  Widget _consentRow(
    String type,
    ConsentItemView? item,
    SettingsController notifier, {
    required bool last,
  }) {
    final meta = _consentMeta[type]!;
    final agreed = item?.agreed ?? false;
    final agreedAt = _agreedAtLabel(item?.agreedAt);
    return DpRowLine(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: Text(meta.label)),
          const SizedBox(width: DpSpacing.sm),
          DpTag(label: meta.required ? '필수' : '선택'),
        ],
      ),
      description: agreedAt == null ? null : Text(agreedAt),
      trailing: meta.required
          ? Icon(DpIcons.stepDone, color: context.dpColors.success)
          // 선택 동의: 현재 동의된 항목만 철회 가능(재동의는 후속).
          : Switch(
              value: agreed,
              onChanged: agreed
                  ? (v) {
                      if (!v) notifier.revokeConsent(type);
                    }
                  : null,
            ),
      last: last,
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
