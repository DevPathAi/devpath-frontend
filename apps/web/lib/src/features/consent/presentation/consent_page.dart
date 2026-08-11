import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../../common/presentation/brand_row.dart';
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
  final FocusNode _birthYearFocus = FocusNode();
  String? _yearError;
  String? _requiredError;

  @override
  void dispose() {
    _birthYear.dispose();
    _birthYearFocus.dispose();
    super.dispose();
  }

  bool get _requiredAllChecked => _ConsentKind.values
      .where((k) => k.required)
      .every((k) => _agreed[k] == true);

  /// 전각 숫자(０-９)를 반각으로 정규화한 뒤 4자리 연도로 파싱한다.
  /// IME 전각 모드 입력을 조용히 버리지 않기 위한 내성 처리.
  int? get _year {
    final normalized = _birthYear.text.trim().replaceAllMapped(
      RegExp('[０-９]'),
      (m) => String.fromCharCode(m.group(0)!.codeUnitAt(0) - 0xFF10 + 0x30),
    );
    if (!RegExp(r'^\d{4}$').hasMatch(normalized)) return null;
    return int.tryParse(normalized);
  }

  /// 버튼은 항상 활성 — 미충족 항목은 비활성 대신 명시적 에러로 안내한다.
  /// (조용한 비활성 버튼은 사용자가 원인을 알 수 없이 갇히는 사고를 냈음: 2026-07-27)
  void _submitPressed() {
    final requiredOk = _requiredAllChecked;
    final year = _year;
    setState(() {
      _requiredError = requiredOk ? null : '필수 항목(이용약관·개인정보)에 모두 동의해 주세요.';
      _yearError = year != null ? null : '출생 연도 4자리를 숫자로 입력해 주세요 (예: 1995)';
    });
    if (!requiredOk || year == null) {
      if (year == null) _birthYearFocus.requestFocus();
      return;
    }
    final items = <ConsentSubmitItem>[
      for (final k in _ConsentKind.values)
        (type: k.wire, agreed: _agreed[k] ?? false),
    ];
    ref
        .read(consentControllerProvider.notifier)
        .submit(items: items, birthYear: year);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(consentControllerProvider);
    if (state is ConsentBlocked) return _BlockedView();

    final c = context.dpColors;
    final submitting = state is ConsentSubmitting;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                brandRow(context),
                const DpPageHeader(
                  title: '가입 전 동의',
                  description: '서비스 이용에 필요한 항목입니다',
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: DpSpacing.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final k in _ConsentKind.values.where(
                        (k) => k.required,
                      ))
                        _consentTile(k),
                      const Divider(height: DpSpacing.xl),
                      TextField(
                        controller: _birthYear,
                        focusNode: _birthYearFocus,
                        keyboardType: TextInputType.number,
                        // digitsOnly 라이브 필터는 IME 조합(한글·전각) 입력을 조용히
                        // 삼킬 수 있어 제거 — 검증은 제출 시 _year 파싱으로 수행한다.
                        inputFormatters: [LengthLimitingTextInputFormatter(4)],
                        decoration: InputDecoration(
                          labelText: '출생 연도 (필수)',
                          hintText: '예: 2000',
                          helperText: '만 14세 미만은 가입할 수 없습니다.',
                          errorText: _yearError,
                        ),
                        onChanged: (_) => setState(() {
                          if (_year != null) _yearError = null;
                        }),
                      ),
                      const SizedBox(height: DpSpacing.lg),
                      Text(
                        '선택 동의',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: c.textSecondary,
                        ),
                      ),
                      for (final k in _ConsentKind.values.where(
                        (k) => !k.required,
                      ))
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
                      if (_requiredError != null) ...[
                        const SizedBox(height: DpSpacing.md),
                        Text(
                          _requiredError!,
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(color: c.danger),
                        ),
                      ],
                      const SizedBox(height: DpSpacing.xl),
                      FilledButton(
                        onPressed: submitting ? null : _submitPressed,
                        child: submitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('동의하고 계속하기'),
                      ),
                      const SizedBox(height: DpSpacing.xl),
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
