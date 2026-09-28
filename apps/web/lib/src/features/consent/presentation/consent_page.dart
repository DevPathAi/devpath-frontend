import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../../common/application/external_link_opener.dart';
import '../../common/presentation/brand_row.dart';
import '../../settings/data/settings_models.dart';
import '../application/consent_controller.dart';
import '../application/consent_source.dart';
import '../state/consent_state.dart';

/// 동의 항목. 백엔드 `ConsentType`(wire) + 필수 여부 + 마이크로카피.
/// 필수: TERMS·PRIVACY / 선택: MARKETING·LCS_ATTACH·ERROR_LOG.
enum _ConsentKind {
  terms(
    'TERMS',
    true,
    '서비스 이용약관 동의',
    '서비스 이용에 필요한 기본 약관입니다.',
    docUrl: 'https://leva.ai.kr/terms',
  ),
  privacy(
    'PRIVACY',
    true,
    '개인정보 수집·이용 동의',
    '학습 진단·경로 제공을 위한 최소한의 정보를 수집합니다.',
    docUrl: 'https://leva.ai.kr/privacy',
  ),
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

  const _ConsentKind(
    this.wire,
    this.required,
    this.title,
    this.desc, {
    this.docUrl,
  });

  final String wire;
  final bool required;
  final String title;
  final String desc;

  /// 전문을 읽을 수 있는 주소. 한 줄 요약만 보여주고 동의를 받는 것은 동의로
  /// 성립하기 어렵다. 문서가 공개된 항목에만 있다.
  final String? docUrl;
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

  /// prefill(GET /consents/me) 응답을 한 번만 폼에 반영하기 위한 플래그.
  /// 없으면 이후 build마다 리스너가 값을 다시 덮어써 사용자의 입력을 지울 수 있다.
  bool _prefillApplied = false;

  @override
  void dispose() {
    _birthYear.dispose();
    _birthYearFocus.dispose();
    super.dispose();
  }

  static final _required = _ConsentKind.values
      .where((k) => k.required)
      .toList(growable: false);
  static final _optional = _ConsentKind.values
      .where((k) => !k.required)
      .toList(growable: false);

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

    // I-2/I-3: 재동의로 재사용되는 화면이라 기존 이용자의 선택 동의·생년을
    // 불러와 미리 반영해야 한다. 실패해도 화면은 떠야 하므로(신규 가입자와
    // 동일 폴백) 로딩 중에만 스피너로 막고, 에러는 그냥 빈 폼으로 넘어간다.
    final prefill = ref.watch(consentPrefillProvider);
    ref.listen<AsyncValue<ConsentsView>>(consentPrefillProvider, (
      previous,
      next,
    ) {
      final view = next.value;
      if (view == null || _prefillApplied) return;
      _prefillApplied = true;
      setState(() {
        // 선택 항목만 prefill한다 — 필수 2종(TERMS·PRIVACY)은 재동의의 목적이
        // "다시 받는 것"이므로 서버 값과 무관하게 항상 false로 시작한다.
        for (final k in _ConsentKind.values.where((k) => !k.required)) {
          final item = view.itemOf(k.wire);
          if (item != null) _agreed[k] = item.agreed;
        }
        if (view.birthYear != null) {
          _birthYear.text = view.birthYear.toString();
        }
      });
    });

    if (prefill.isLoading) {
      return const Scaffold(body: DpLoading(label: '동의 항목을 불러오는 중'));
    }

    // 기존 이용자 판별: 조회된 동의 이력(items)이 있으면 재동의로 본다.
    // prefill이 에러였다면 valueOrNull이 null이라 신규 가입자와 같게 처리된다.
    final isReturningUser = prefill.value?.items.isNotEmpty ?? false;

    final c = context.dpColors;
    final submitting = state is ConsentSubmitting;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            // 시안 `.narrow{max-width:760px}`. 440 은 `.chk` 의 라벨+설명+
            // 「전문 보기」 3열을 한 줄에 담기 좁았다.
            key: const ValueKey('consent-narrow'),
            constraints: BoxConstraints(
              maxWidth: context.appTokens.readableMaxWidth,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                brandRow(context),
                DpPageHeader(
                  // 셸 밖 화면이라 거터를 줄 셸이 없다 — 헤더가 스스로 준다.
                  // 없으면 제목이 화면 끝(x=0)에 붙어 형제들과 좌측선이 갈린다.
                  gutter: true,
                  title: isReturningUser ? '서비스 이용약관 재동의' : '가입 전 동의',
                  description: isReturningUser
                      ? '약관이 새로 게시되어 다시 동의를 받습니다'
                      : '서비스 이용에 필요한 항목입니다',
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: DpSpacing.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 시안 `.chk` 패널 — 필수 항목.
                      DpPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final k in _required)
                              _consentTile(k, last: k == _required.last),
                          ],
                        ),
                      ),
                      const SizedBox(height: DpSpacing.xl),
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
                      const SizedBox(height: DpSpacing.sm),
                      // 시안 `.chk` 패널 — 선택 항목.
                      DpPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final k in _optional)
                              _consentTile(k, last: k == _optional.last),
                          ],
                        ),
                      ),
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

  /// 시안 `.chk` 한 행 — 체크 + 라벨·설명 + 우측 「전문 보기」.
  /// `DpCheckRow` 는 체크+라벨을 한 노드로 묶고 우측 링크는 별개 노드로 남긴다
  /// (`CheckboxListTile` 은 셋을 병합해 스크린리더가 링크를 놓쳤다).
  Widget _consentTile(_ConsentKind k, {required bool last}) => DpCheckRow(
    key: ValueKey('consent-${k.name}-row'),
    value: _agreed[k] ?? false,
    onChanged: (v) => setState(() => _agreed[k] = v),
    last: last,
    label: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: Text(k.title)),
        const SizedBox(width: DpSpacing.sm),
        DpTag(label: k.required ? '필수' : '선택'),
      ],
    ),
    description: Text(k.desc),
    // 전문은 새 탭으로 연다. 동의 화면을 떠나면 여기까지 온 맥락(OAuth 직후)이
    // 끊긴다. 같은 문구의 링크가 둘이라 `semanticsLabel` 로 구분한다.
    trailing: k.docUrl == null
        ? null
        : DpLink.inline(
            key: ValueKey('consent-${k.name}-doc'),
            text: '전문 보기',
            semanticsLabel: '${k.title} 전문 보기',
            onTap: () => ref.read(externalLinkOpenerProvider).open(k.docUrl!),
          ),
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
          // 시안 `.narrow` — 차단 안내도 같은 폭을 쓴다.
          key: const ValueKey('consent-blocked-narrow'),
          constraints: BoxConstraints(
            maxWidth: context.appTokens.readableMaxWidth,
          ),
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
                const SizedBox(height: DpSpacing.sm),
                // I-3: 기존 이용자가 재동의 중 출생 연도를 잘못 입력해도 같은
                // 화면을 본다. 로그아웃 버튼만 있으면 "계정이 잘렸다"는 신호로
                // 읽힌다 — 재시도 경로가 있음을 알려준다.
                Text(
                  '출생 연도를 잘못 입력하셨다면 다시 로그인해 재시도할 수 있습니다.',
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: c.textSecondary),
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
