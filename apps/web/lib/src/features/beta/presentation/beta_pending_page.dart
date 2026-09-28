import 'dart:async';

import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../providers/api_providers.dart';
import '../../auth/application/auth_controller.dart';
import '../../common/presentation/brand_row.dart';

/// 미승인(BETA_PENDING) 사용자 대기 페이지. 5초 주기로 GET /beta/status를 폴링해
/// APPROVED면 자동 재-OAuth(login(provider)), EXPIRED면 재로그인 버튼을 노출한다.
class BetaPendingPage extends ConsumerStatefulWidget {
  const BetaPendingPage({super.key});

  @override
  ConsumerState<BetaPendingPage> createState() => _BetaPendingPageState();
}

class _BetaPendingPageState extends ConsumerState<BetaPendingPage> {
  Timer? _timer;
  bool _expired = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _poll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    try {
      final data = await ref
          .read(apiClientProvider)
          .get<Map<String, dynamic>>('/beta/status');
      if (!mounted) return;
      final status = BetaStatus.fromJson(data);
      switch (status.status) {
        case BetaStatusKind.approved:
          _timer?.cancel();
          final p = status.provider;
          if (p != null) {
            ref.read(authControllerProvider.notifier).login(provider: p);
          } else {
            context.go('/login');
          }
        case BetaStatusKind.expired:
          _timer?.cancel();
          setState(() => _expired = true);
        case BetaStatusKind.pending:
          break;
      }
    } catch (_) {
      // 일시 오류는 무시하고 다음 주기 재시도.
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dpColors;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        // 시안 `beta` 는 `.narrow.center` 다 — 내용이 뷰포트보다 짧으면 세로로도
        // 가운데 온다(원본도 `Center` 밖에 두었다). `Center` 를 스크롤 뷰 밖에
        // 둬야 짧을 때 가운데, 길 때 스크롤이 된다.
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 셸 밖 화면의 유일한 제품 정체성 표시.
                brandRow(context),
                const SizedBox(height: DpSpacing.xxl),
                // 시안 `beta` 는 `.narrow.center` 다 — 좌측 정렬 페이지 헤더와
                // 맞지 않아 상태를 태그로, 제목을 headlineSmall 로 직접 그린다.
                Center(
                  child: ConstrainedBox(
                    key: const ValueKey('beta-narrow'),
                    constraints: BoxConstraints(
                      maxWidth: context.appTokens.readableMaxWidth,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(DpSpacing.xl),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // 아이콘이 아니라 태그로 상태를 알린다 — 스크린리더가
                          // 읽을 수 있고 시안의 면 문법과도 맞는다.
                          DpTag(label: _expired ? '대기 만료' : '베타 대기'),
                          const SizedBox(height: DpSpacing.md),
                          Text(
                            _expired ? '다시 로그인해 확인해 주세요' : '승인되면 알려드립니다',
                            style: text.headlineSmall,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: DpSpacing.sm),
                          Text(
                            _expired
                                ? '대기 세션이 만료되었어요. 승인 여부는 이메일로 안내됩니다.'
                                : '베타 대기자 명단에 등록되었어요. 승인되면 이메일로 알려드리고, 이 화면에서 자동으로 입장합니다.',
                            style: text.bodyMedium?.copyWith(
                              color: c.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: DpSpacing.xl),
                          if (_expired)
                            FilledButton(
                              onPressed: () => context.go('/login'),
                              child: const Text('다시 로그인'),
                            )
                          else
                            const DpLoading(label: '승인을 기다리는 중'),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: DpSpacing.xxl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
