import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../application/consent_controller.dart';
import '../application/consent_source.dart';
import '../state/consent_state.dart';

/// 동의 항목. 백엔드 `ConsentType`(wire) + 필수 여부 + 마이크로카피.
/// 필수: TERMS·PRIVACY / 선택: MARKETING·LCS_ATTACH·ERROR_LOG.
enum _ConsentKind {
  terms('TERMS', true, '서비스 이용약관 동의', '서비스 이용에 필요한 기본 약관입니다.'),
  privacy('PRIVACY', true, '개인정보 수집·이용 동의', '학습 진단·경로 제공을 위한 최소한의 정보를 수집합니다.'),
  marketing('MARKETING', false, '마케팅 정보 수신 동의', '학습 팁과 이벤트 소식을 이메일로 받아봅니다.'),
  lcsAttach(
    'LCS_ATTACH',
    false,
    '학습 맥락 자동 첨부 동의',
    '질문할 때 최근 학습 맥락을 자동으로 덧붙입니다.',
  ),
  errorLog(
    'ERROR_LOG',
    false,
    '오류 진단 로그 수집 동의',
    '오류가 나면 진단 로그를 수집해 품질 개선에 씁니다.',
  );

  const _ConsentKind(this.wire, this.required, this.title, this.desc);

  final String wire;
  final bool required;
  final String title;
  final String desc;
}

/// 회원가입 필수 동의 gate 화면. OAuth 직후·진단 전에 노출된다(라우터 게이트).
/// 필수 2종 + 생년 제출 → POST /consents. 만 14세 미만은 서버가 차단(→차단 화면).
class ConsentPage extends ConsumerStatefulWidget {
  const ConsentPage({super.key});

  @override
  ConsumerState<ConsentPage> createState() => _ConsentPageState();
}

class _ConsentPageState extends ConsumerState<ConsentPage> {
  final Map<_ConsentKind, bool> _agreed = {
    for (final k in _ConsentKind.values) k: false,
  };
  final TextEditingController _birthYear = TextEditingController();

  @override
  void dispose() {
    _birthYear.dispose();
    super.dispose();
  }

  bool get _requiredAllChecked => _ConsentKind.values
      .where((k) => k.required)
      .every((k) => _agreed[k] == true);

  int? get _year => int.tryParse(_birthYear.text.trim());

  bool get _canSubmit => _requiredAllChecked && _year != null;

  void _submit() {
    final items = <ConsentSubmitItem>[
      for (final k in _ConsentKind.values)
        (type: k.wire, agreed: _agreed[k] ?? false),
    ];
    ref
        .read(consentControllerProvider.notifier)
        .submit(items: items, birthYear: _year!);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(consentControllerProvider);
    if (state is ConsentBlocked) return _BlockedView();

    final c = context.dpColors;
    final submitting = state is ConsentSubmitting;

    return Scaffold(
      appBar: AppBar(title: const Text('가입 전 동의')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(DpSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '서비스 이용을 위해 아래 항목에 동의해 주세요',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: DpSpacing.lg),
                for (final k in _ConsentKind.values.where((k) => k.required))
                  _consentTile(k),
                const Divider(height: DpSpacing.xl),
                TextField(
                  controller: _birthYear,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  decoration: const InputDecoration(
                    labelText: '출생 연도 (필수)',
                    hintText: '예: 2000',
                    helperText: '만 14세 미만은 가입할 수 없습니다.',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: DpSpacing.lg),
                Text(
                  '선택 동의',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(color: c.textSecondary),
                ),
                for (final k in _ConsentKind.values.where((k) => !k.required))
                  _consentTile(k),
                if (state is ConsentError) ...[
                  const SizedBox(height: DpSpacing.md),
                  Text(
                    state.message,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: c.danger),
                  ),
                ],
                const SizedBox(height: DpSpacing.xl),
                FilledButton(
                  onPressed: _canSubmit && !submitting ? _submit : null,
                  child: submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('동의하고 계속하기'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _consentTile(_ConsentKind k) => CheckboxListTile(
    value: _agreed[k] ?? false,
    onChanged: (v) => setState(() => _agreed[k] = v ?? false),
    controlAffinity: ListTileControlAffinity.leading,
    contentPadding: EdgeInsets.zero,
    title: Text(k.title),
    subtitle: Text(k.desc),
  );
}

/// 만 14세 미만 차단 안내 + 로그아웃.
class _BlockedView extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.dpColors;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(DpSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(DpIcons.error, color: c.danger, size: 48),
                const SizedBox(height: DpSpacing.lg),
                Text(
                  '가입할 수 없어요',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: DpSpacing.sm),
                Text(
                  '만 14세 미만은 서비스에 가입할 수 없습니다.',
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: c.textSecondary),
                ),
                const SizedBox(height: DpSpacing.xl),
                OutlinedButton(
                  onPressed: () =>
                      ref.read(authControllerProvider.notifier).logout(),
                  child: const Text('로그아웃'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
